import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';

class PrivacyNoticeScreen extends StatefulWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  State<PrivacyNoticeScreen> createState() => _PrivacyNoticeScreenState();
}

class _PrivacyNoticeScreenState extends State<PrivacyNoticeScreen> {
  bool _termsAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 44, 18, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFD8DDE6))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('←', style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
                  ),
                  const Spacer(),
                  const TranslatedText('Privacy Notice',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText('Before we create your ABHA',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                      ),
                      const SizedBox(height: 12),
                      const TranslatedText('We need your consent to create your ABHA and manage your health records securely.',
                        style: TextStyle(fontSize: 15, color: Color(0xFF9BA8BB)),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFD8DDE6)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/curenet_logo.png',
                                  width: 52,
                                  height: 52,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.shield_outlined, size: 52, color: Color(0xFF00A3A3));
                                  },
                                ),
                                const SizedBox(width: 8),
                                const TranslatedText('Your Data is Safe',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const TranslatedText('We use Zero-Knowledge Proofs to ensure your medical records are never exposed without your explicit consent. Your ABHA is protected under DPDP Act 2023.',
                              style: TextStyle(fontSize: 14, color: Color(0xFF5A6880)),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _termsAgreed = !_termsAgreed),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFD8DDE6)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: _termsAgreed
                                        ? const Center(
                                      child: Text('✓', style: TextStyle(fontSize: 16, color: Color(0xFF00A3A3))),
                                    )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RichText(
                                    text: const TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'I agree to the ',
                                          style: TextStyle(fontSize: 14, color: Color(0xFF5A6880)),
                                        ),
                                        TextSpan(
                                          text: 'Terms & Conditions ',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                                        ),
                                        TextSpan(
                                          text: 'and ',
                                          style: TextStyle(fontSize: 14, color: Color(0xFF5A6880)),
                                        ),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                                        ),
                                        TextSpan(
                                          text: '.',
                                          style: TextStyle(fontSize: 14, color: Color(0xFF5A6880)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: ElevatedButton(
                onPressed: _termsAgreed ? () => Navigator.pushNamed(context, '/register-abha') : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _termsAgreed ? const Color(0xFF00A3A3) : const Color(0xFFD8DDE6),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const TranslatedText('Create ABHA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}