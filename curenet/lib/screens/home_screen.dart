import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/translated_text.dart';
import '../core/persona.dart';
import '../core/data_mode.dart';
import '../core/auth_provider.dart';
import '../services/ocr_service.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request camera permission on startup so it's ready for scanning
    await Permission.camera.request();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userProfile;
    final String userName = (user != null && user['name'] != null && user['name'].toString().trim().isNotEmpty)
        ? user['name'].toString()
        : (DataMode.activeUserId == DataMode.arjunId ? Persona.name : 'Live User');
    final String abha = (user != null && user['abha'] != null && user['abha'].toString().trim().isNotEmpty)
        ? user['abha'].toString()
        : (DataMode.activeUserId == DataMode.arjunId ? Persona.abhaNumber : '91-LIVE-0000-0001');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 8),


              // ── TOP HEADER ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00A3A3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                              ),
                              Text(
                                abha,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.translate, color: Color(0xFF0D2240)),
                      onPressed: () => Navigator.pushNamed(context, '/language-select'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0D2240)),
                      onPressed: () => Navigator.pushNamed(context, '/notifications'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── GREETING (long-press = hidden dev toggle) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onLongPress: () => _showDevToggle(context),
                      child: TranslatedText(
                        "Hello, ${userName.split(' ')[0]}",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── ABHAy AI BIG CARD ──
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/chat'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A3A3), Color(0xFF1A3A5C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(child: Icon(Icons.smart_toy, size: 28, color: Colors.white)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                TranslatedText(
                                  "Ask Abhya AI",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                TranslatedText(
                                  "Anything about your health",
                                  style: TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const TranslatedText(
                          "What medications am I on right now?",
                          style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── QUICK ACTIONS GRID ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _quickAction(context, Icons.list_alt, "Records", '/records'),
                    _quickAction(context, Icons.qr_code_scanner, "Share QR", '/qr-share'),
                    _quickAction(context, Icons.document_scanner, "Scan Doc", '/doc-scan'),
                    _quickAction(context, Icons.lock_rounded, "Locker", '/health-locker'),
                  ],
                ),
              ),

              // ── DYNAMIC RECENT RECORDS (max 3, hidden if empty) ──
              FutureBuilder<List<Map<String, dynamic>>>(
                future: DataMode.activeUserId == DataMode.arjunId 
                    ? Future.value(<Map<String, dynamic>>[]) 
                    : OcrService.getLocalRecords(),
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> records = [];

                  if (DataMode.activeUserId == DataMode.arjunId) {
                    // Arjun demo fallback
                    records = Persona.history.take(3).map((h) => <String, dynamic>{
                      'title': (h['event'] as String? ?? 'Record').split(' — ').first,
                      'date': h['date'],
                      'category': h['category'],
                    }).toList();
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    records = snapshot.data!.take(3).toList();
                  }

                  // If no records at all, hide entire section
                  if (records.isEmpty) return const SizedBox.shrink();

                  return Column(
                    children: [
                      // Header row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const TranslatedText("Recent Records", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240))),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/records'),
                              child: const TranslatedText("View all →", style: TextStyle(fontSize: 13, color: Color(0xFF00A3A3), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Record cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: records.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _wideRecordCard(
                              context,
                              r['title']?.toString() ?? 'Medical Record',
                              r['displayDate']?.toString() ?? r['date']?.toString() ?? '',
                              _getCategoryIcon(r['category']?.toString() ?? ''),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFD8DDE6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomNavItem(Icons.home, "Home", true),
            _bottomNavItem(Icons.smart_toy, "ABHAy", false, onTap: () => Navigator.pushNamed(context, '/chat')),
            _scanButton(context),
            _bottomNavItem(Icons.list_alt, "Records", false, onTap: () => Navigator.pushNamed(context, '/records')),
            _bottomNavItem(Icons.share, "Share", false, onTap: () => Navigator.pushNamed(context, '/qr-share')),
          ],
        ),
      ),
    );
  }

  // ── IDENTITY INFO PANEL (triple-tap on greeting) ──
  void _showDevToggle(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userProfile;
    final isArjun = DataMode.activeUserId == DataMode.arjunId;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isArjun ? Icons.person : Icons.person_outline, 
                 color: isArjun ? const Color(0xFFE07B39) : const Color(0xFF00A3A3), size: 22),
            const SizedBox(width: 8),
            Text(isArjun ? "Demo Identity" : "Live Identity", 
                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow("Identity", isArjun ? "Arjun Mishra (Demo)" : "Live User"),
            _infoRow("User ID", DataMode.activeUserId),
            _infoRow("AI Context", isArjun ? "Persona + Uploads" : "Uploads Only"),
            _infoRow("Data", isArjun ? "Hardcoded + Uploaded" : "Uploaded Only"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isArjun ? const Color(0xFFFFF3E0) : const Color(0xFFE0F7FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isArjun 
                    ? "📋 Demo mode: AI has access to Arjun Mishra's hardcoded medical history."
                    : "🔒 Live mode: AI only knows what you upload. No pre-loaded data.",
                style: const TextStyle(fontSize: 12, color: Color(0xFF5A6880)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "To switch identity, logout and login with a different phone number.",
              style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text("Switch User", style: TextStyle(color: Color(0xFFD32F2F))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ──
  Widget _quickAction(BuildContext context, IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
            ),
            child: Center(child: Icon(icon, size: 24, color: const Color(0xFF00A3A3))),
          ),
          const SizedBox(height: 6),
          TranslatedText(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5A6880))),
        ],
      ),
    );
  }

  Widget _wideRecordCard(BuildContext context, String title, String date, IconData icon) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/records'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8DDE6).withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Icon(icon, color: const Color(0xFF00A3A3), size: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9BA8BB), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFD8DDE6)),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    category = category.toLowerCase();
    if (category.contains('lab')) return Icons.science_rounded;
    if (category.contains('prescription')) return Icons.medication_rounded;
    if (category.contains('scan') || category.contains('x-ray')) return Icons.biotech_rounded;
    if (category.contains('eye')) return Icons.visibility_rounded;
    return Icons.assignment_rounded;
  }

  Widget _bottomNavItem(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE8F7F7) : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(child: Icon(icon, size: 22, color: isActive ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
          ),
          TranslatedText(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB),
            ),
          ),
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
              BoxShadow(
                color: const Color(0xFF00A3A3).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.camera_alt, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}