import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';

class ForgotAbhaScreen extends StatelessWidget {
  const ForgotAbhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
                ),
                const SizedBox(width: 14),
                const TranslatedText("Forgot ABHA Number",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TranslatedText("You can recover your ABHA number using Aadhaar number or registered mobile number.",
                    style: TextStyle(fontSize: 14, color: Color(0xFF5A6880), height: 1.5),
                  ),
                  const SizedBox(height: 32),

                  // Aadhaar Option
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/forgot-abha-aadhaar'),
                    child: _recoveryOption("Aadhaar Number", Icons.badge),
                  ),

                  const SizedBox(height: 12),

                  // Mobile Option
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/forgot-abha-mobile'),
                    child: _recoveryOption("Mobile Number", Icons.phone_android),
                  ),

                  const Spacer(),

                  ElevatedButton(
                    onPressed: () {}, // Handled by options above
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const TranslatedText("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recoveryOption(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD8DDE6), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: const Color(0xFF0D2240)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
            ),
          ),
          const Text("›", style: TextStyle(fontSize: 22, color: Color(0xFF9BA8BB))),
        ],
      ),
    );
  }
}