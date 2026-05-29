import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/data_mode.dart';

/// Global service that monitors for incoming doctor access requests.
/// Runs a background poller and shows a dialog automatically when
/// a new request arrives, regardless of which screen the user is on.
class AccessRequestMonitor {
  static AccessRequestMonitor? _instance;
  static AccessRequestMonitor get instance =>
      _instance ??= AccessRequestMonitor._();

  AccessRequestMonitor._();

  Timer? _pollTimer;
  bool _isDialogShowing = false;
  final Set<String> _handledRequestIds = {};
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Call once from main.dart with the navigator key.
  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    start();
  }

  void start() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
    _poll(); // immediate first check
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    stop();
    _instance = null;
  }

  Future<void> _poll() async {
    if (_isDialogShowing) return;
    try {
      final userId = DataMode.activeUserId;
      final res = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/access/pending/$userId'),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final requests = List<Map<String, dynamic>>.from(data['requests'] ?? []);

        if (requests.isNotEmpty) {
          debugPrint('[AccessMonitor] Found ${requests.length} pending requests');
        }

        // Find the first request we haven't already handled
        for (final req in requests) {
          final reqId = req['requestId']?.toString() ?? '';
          if (reqId.isNotEmpty && !_handledRequestIds.contains(reqId)) {
            debugPrint('[AccessMonitor] Showing dialog for request $reqId');
            _showAccessDialog(req);
            break;
          }
        }
      }
    } catch (e) {
      // Silently ignore — backend might not be running
      debugPrint('[AccessMonitor] Poll error: $e');
    }
  }

  void _showAccessDialog(Map<String, dynamic> request) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    _isDialogShowing = true;
    final requestId = request['requestId']?.toString() ?? '';
    final doctorInfo = request['doctorInfo'] as Map<String, dynamic>? ?? {};
    final doctorName = doctorInfo['name']?.toString() ?? 'A Doctor';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AccessRequestDialog(
        requestId: requestId,
        doctorName: doctorName,
        doctorDevice: doctorInfo['device']?.toString() ?? '',
        onRespond: (action) async {
          Navigator.of(ctx).pop();
          _isDialogShowing = false;
          _handledRequestIds.add(requestId);
          await _respond(requestId, action, context);
        },
      ),
    );
  }

  Future<void> _respond(String requestId, String action, BuildContext context) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/access/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'action': action}),
      ).timeout(const Duration(seconds: 8));

      if (action == 'approved') {
        _navigatorKey?.currentState?.pushNamed('/access-ok', arguments: requestId);
      }
    } catch (e) {
      debugPrint('[AccessMonitor] Respond error: $e');
    }
  }
}

class _AccessRequestDialog extends StatelessWidget {
  final String requestId;
  final String doctorName;
  final String doctorDevice;
  final Function(String action) onRespond;

  const _AccessRequestDialog({
    required this.requestId,
    required this.doctorName,
    required this.doctorDevice,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulse icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE07B39).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.medical_services, size: 32, color: Color(0xFFE07B39)),
              ),
            ),
            const SizedBox(height: 16),

            const Text("Doctor Access Request",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
            ),
            const SizedBox(height: 8),

            Text("$doctorName wants to view your health records",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF5A6880), height: 1.4),
            ),
            const SizedBox(height: 6),

            if (doctorDevice.isNotEmpty)
              Text(doctorDevice.length > 40 ? '${doctorDevice.substring(0, 40)}...' : doctorDevice,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
              ),

            const SizedBox(height: 16),

            // What they'll see
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _row(Icons.check_circle, "Emergency health card", const Color(0xFF22A36A)),
                  _row(Icons.check_circle, "Medications & allergies", const Color(0xFF22A36A)),
                  _row(Icons.check_circle, "Latest vitals", const Color(0xFF22A36A)),
                  _row(Icons.timer, "Expires in 30 minutes", const Color(0xFF00A3A3)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onRespond('denied'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD63B3B),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Deny", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onRespond('approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Approve", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF0D2240))),
        ],
      ),
    );
  }
}
