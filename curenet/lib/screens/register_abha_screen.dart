import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';

class RegisterAbhaScreen extends StatelessWidget {
  const RegisterAbhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String abhaAddress = 'labish123@abdm';

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
                  const TranslatedText('Your ABHA Created',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.verified, size: 40, color: Color(0xFF00A3A3)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const TranslatedText('Congratulations!',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                    ),
                    const SizedBox(height: 12),
                    const TranslatedText('Your ABHA is now ready. Use it to securely manage and share your health records.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF5A6880)),
                    ),
                    const SizedBox(height: 32),
                    // ABHA Card (v5 exact)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF00A3A3)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_circle, size: 20, color: Color(0xFF00A3A3)),
                              SizedBox(width: 8),
                              TranslatedText('Your ABHA Address',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            abhaAddress,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D2240),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              // Copy logic (add clipboard package)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: TranslatedText('ABHA address copied!')),
                              );
                            },
                            child: const TranslatedText('Copy Address', style: TextStyle(color: Color(0xFF00A3A3))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A3A3),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const TranslatedText('Get Started',
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