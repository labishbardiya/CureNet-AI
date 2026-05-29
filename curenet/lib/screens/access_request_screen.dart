import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/data_mode.dart';
import '../core/translated_text.dart';

class AccessRequestScreen extends StatefulWidget {
  const AccessRequestScreen({super.key});

  @override
  State<AccessRequestScreen> createState() => _AccessRequestScreenState();
}

class _AccessRequestScreenState extends State<AccessRequestScreen> {
  Timer? _pollTimer;
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  String? _error;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _fetchPendingRequests(); // Immediate first fetch
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchPendingRequests();
    });
  }

  Future<void> _fetchPendingRequests() async {
    try {
      final userId = DataMode.activeUserId;
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/access/pending/$userId'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final requests = List<Map<String, dynamic>>.from(data['requests'] ?? []);
        if (mounted) {
          setState(() {
            _pendingRequests = requests;
            _isLoading = false;
            _error = null;
            _failCount = 0;
          });
        }
      }
    } catch (e) {
      _failCount++;
      if (mounted && _failCount >= 3) {
        setState(() {
          _isLoading = false;
          _error = 'Could not reach CureNet server.\nMake sure the backend is running and your phone is connected to the same network.';
        });
      } else if (mounted && _isLoading) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _respondToRequest(String requestId, String action) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/access/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'action': action}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (action == 'approved') {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/access-ok', arguments: requestId);
          }
        } else {
          // Denied — remove from list and show feedback
          setState(() {
            _pendingRequests.removeWhere((r) => r['requestId'] == requestId);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access request denied'),
                backgroundColor: Color(0xFFD63B3B),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to respond: $e'),
            backgroundColor: const Color(0xFFD63B3B),
          ),
        );
      }
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Amber Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE07B39), Color(0xFFC9601A)],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText("Access Requests",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      TranslatedText(
                        _pendingRequests.isEmpty ? "No pending requests" : "${_pendingRequests.length} pending request${_pendingRequests.length > 1 ? 's' : ''}",
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A3A3)))
                : _error != null
                    ? _buildErrorState()
                    : _pendingRequests.isEmpty
                        ? _buildEmptyState()
                        : _buildRequestsList(),
          ),
        ],
      ),

      // Bottom Navigation
      bottomNavigationBar: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFD8DDE6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home, "Home", false, () => Navigator.pushReplacementNamed(context, '/home')),
            _navItem(Icons.smart_toy, "ABHAy", false, () => Navigator.pushReplacementNamed(context, '/chat')),
            _scanButton(context),
            _navItem(Icons.list_alt, "Records", false, () => Navigator.pushReplacementNamed(context, '/records')),
            _navItem(Icons.share, "Share", false, () => Navigator.pushReplacementNamed(context, '/qr-share')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(child: Icon(Icons.verified_user, size: 40, color: Color(0xFF00A3A3))),
            ),
            const SizedBox(height: 24),
            const TranslatedText("No Pending Requests",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0D2240)),
            ),
            const SizedBox(height: 8),
            const TranslatedText(
              "When a doctor scans your QR code, their access request will appear here for your approval.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF5A6880), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFF9BA8BB)),
            const SizedBox(height: 16),
            TranslatedText(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF5A6880)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final req = _pendingRequests[index];
        final doctorInfo = req['doctorInfo'] as Map<String, dynamic>? ?? {};
        final doctorName = doctorInfo['name']?.toString() ?? 'Doctor';
        final doctorDevice = doctorInfo['device']?.toString() ?? 'Unknown Device';
        final requestId = req['requestId']?.toString() ?? '';
        final timeAgo = _timeAgo(req['createdAt']?.toString());

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8DDE6)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              // Doctor Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3A8A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: Icon(Icons.person, size: 26, color: Color(0xFF1A3A8A))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctorName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0D2240)),
                          ),
                          Text(doctorDevice.length > 30 ? '${doctorDevice.substring(0, 30)}...' : doctorDevice,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)),
                          ),
                          if (timeAgo.isNotEmpty)
                            Text('Requested $timeAgo',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE07B39)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // What they will see
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText("THEY WILL SEE",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    _permissionRow("Emergency health card summary"),
                    _permissionRow("Active medications list"),
                    _permissionRow("Latest vitals & allergies"),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // What they won't see
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD63B3B).withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText("THEY WILL NOT SEE",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD63B3B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    _permissionRow("Full prescription details", isRed: true),
                    _permissionRow("Personal notes & emergency contacts", isRed: true),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text("Access expires in 30 minutes after approval",
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _respondToRequest(requestId, 'denied'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD63B3B),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const TranslatedText("✗ Deny",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _respondToRequest(requestId, 'approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A3A3),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const TranslatedText("✓ Approve",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _permissionRow(String text, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(isRed ? "✗" : "✓",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isRed ? const Color(0xFFD63B3B) : const Color(0xFF22A36A)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF0D2240))),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
          TranslatedText(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
        ],
      ),
    );
  }

  Widget _scanButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ModalRoute.of(context)?.settings.name != '/doc-scan') {
          Navigator.pushNamed(context, '/doc-scan');
        }
      },
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00A3A3), Color(0xFF00C4C4)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF00A3A3).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: const Center(child: Icon(Icons.camera_alt, size: 28, color: Colors.white)),
        ),
      ),
    );
  }
}