import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0D2240),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                const TranslatedText("Notifications",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _notificationCard(
                  context: context,
                  icon: Icons.list_alt,
                  iconColor: const Color(0xFF00A3A3),
                  title: "New Health Record Added",
                  subtitle: "Dr. Meena Kapoor added a new prescription record from Apollo Spectra.",
                  time: "Today · 11:30 AM",
                  isUnread: true,
                ),
                const SizedBox(height: 12),
                _notificationCard(
                  context: context,
                  icon: Icons.notifications,
                  iconColor: const Color(0xFFD63B3B),
                  title: "Doctor Access Request",
                  subtitle: "Dr. Suresh Kumar (Apollo Spectra) is requesting access to your health records.",
                  time: "Today · 11:40 AM",
                  isUnread: true,
                ),
                const SizedBox(height: 12),
                _notificationCard(
                  context: context,
                  icon: Icons.check_circle,
                  iconColor: const Color(0xFF22A36A),
                  title: "Follow-up Reminder",
                  subtitle: "Your cardiology follow-up with Dr. Meena Kapoor is due in 3 days.",
                  time: "Yesterday · 9:00 AM",
                  isUnread: false,
                ),
                const SizedBox(height: 12),
                _notificationCard(
                  context: context,
                  icon: Icons.medication,
                  iconColor: const Color(0xFF6B4E9B),
                  title: "Medication Reminder",
                  subtitle: "Take Amlodipine 5mg — your daily morning dose.",
                  time: "Yesterday · 8:00 AM",
                  isUnread: false,
                ),
              ],
            ),
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

  Widget _notificationCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
  }) {
    final speakText = '$title. $subtitle. $time.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Icon(icon, size: 20, color: iconColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5A6880), height: 1.4),
                ),
                const SizedBox(height: 8),
                TranslatedText(
                  time,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up, color: Color(0xFF00A3A3), size: 22),
            onPressed: () async {
              final ok = await VoiceHelper.speak(speakText);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(VoiceHelper.lastError ?? 'Voice readout failed.'),
                    backgroundColor: const Color(0xFF0D2240),
                  ),
                );
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          if (isUnread)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00A3A3),
                shape: BoxShape.circle,
              ),
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