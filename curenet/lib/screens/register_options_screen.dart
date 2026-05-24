import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';

class RegisterOptionsScreen extends StatefulWidget {
  const RegisterOptionsScreen({super.key});

  @override
  State<RegisterOptionsScreen> createState() => _RegisterOptionsScreenState();
}

class _RegisterOptionsScreenState extends State<RegisterOptionsScreen> {
  String selectedMethod = '';

  void selectMethod(String method) {
    setState(() => selectedMethod = method);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D2240),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/curenet_logo.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.health_and_safety, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const TranslatedText('Create ABHA',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText('Create your ABHA',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                    ),
                    const SizedBox(height: 4),
                    const TranslatedText('Your free digital health ID',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9BA8BB)),
                    ),
                    const SizedBox(height: 32),

                    // Aadhaar Option (Recommended)
                    InkWell(
                      onTap: () => selectMethod('aadhaar'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: selectedMethod == 'aadhaar' ? const Color(0xFFE8F7F7) : Colors.transparent,
                          border: Border.all(
                            color: selectedMethod == 'aadhaar' ? const Color(0xFF00A3A3) : const Color(0xFFD8DDE6),
                            width: selectedMethod == 'aadhaar' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.fingerprint_outlined, size: 24, color: Color(0xFF00A3A3)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const TranslatedText('Use Aadhaar Number',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                                      ),
                                      if (selectedMethod == 'aadhaar')
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF00A3A3)),
                                    ],
                                  ),
                                  const TranslatedText('Quick verification with your Aadhaar',
                                    style: TextStyle(fontSize: 14, color: Color(0xFF9BA8BB)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Mobile Option
                    InkWell(
                      onTap: () => selectMethod('mobile'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: selectedMethod == 'mobile' ? const Color(0xFFE8F7F7) : Colors.transparent,
                          border: Border.all(
                            color: selectedMethod == 'mobile' ? const Color(0xFF00A3A3) : const Color(0xFFD8DDE6),
                            width: selectedMethod == 'mobile' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.phone_android_outlined, size: 24, color: Color(0xFF00A3A3)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const TranslatedText('Use Mobile Number',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                                      ),
                                      if (selectedMethod == 'mobile')
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF00A3A3)),
                                    ],
                                  ),
                                  const TranslatedText('Create with your Indian mobile number',
                                    style: TextStyle(fontSize: 14, color: Color(0xFF9BA8BB)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Already have ABHA
                    InkWell(
                      onTap: () => selectMethod('login'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: selectedMethod == 'login' ? const Color(0xFFE8F7F7) : Colors.transparent,
                          border: Border.all(
                            color: selectedMethod == 'login' ? const Color(0xFF00A3A3) : const Color(0xFFD8DDE6),
                            width: selectedMethod == 'login' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.account_circle_outlined, size: 24, color: Color(0xFF00A3A3)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const TranslatedText('Already have ABHA',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                                      ),
                                      if (selectedMethod == 'login')
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF00A3A3)),
                                    ],
                                  ),
                                  const TranslatedText('Login with your existing ABHA ID',
                                    style: TextStyle(fontSize: 14, color: Color(0xFF9BA8BB)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Continue Button
            Padding(
              padding: const EdgeInsets.all(18),
              child: ElevatedButton(
                onPressed: selectedMethod.isEmpty
                    ? null
                    : () {
                        if (selectedMethod == 'aadhaar') {
                          Navigator.pushNamed(context, '/create-abha-aadhaar');
                        } else if (selectedMethod == 'mobile') {
                          Navigator.pushNamed(context, '/create-abha-mobile');
                        } else if (selectedMethod == 'login') {
                          Navigator.pushNamed(context, '/login-options');
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedMethod.isEmpty ? const Color(0xFFD8DDE6) : const Color(0xFF00A3A3),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: TranslatedText('Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: selectedMethod.isEmpty ? const Color(0xFF9BA8BB) : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}