import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';
import '../services/abdm_service.dart';
import '../core/abdm_crypto.dart';

class CreateAbhaMobileScreen extends StatefulWidget {
  const CreateAbhaMobileScreen({super.key});

  @override
  State<CreateAbhaMobileScreen> createState() => _CreateAbhaMobileScreenState();
}

class _CreateAbhaMobileScreenState extends State<CreateAbhaMobileScreen> {
  final TextEditingController _mobileController = TextEditingController();
  bool _termsAgreed = false;
  bool _isLoading = false;

  Future<void> _handleContinue() async {
    final mobile = _mobileController.text.trim();
    if (mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 10-digit mobile number")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Get Public Key
      final keyData = await AbdmService.getPublicKey();
      final publicKeyPem = keyData['publicKey'] as String?;
      if (publicKeyPem == null) throw Exception("Failed to retrieve encryption key");

      // 2. Encrypt Mobile
      final encryptedMobile = AbdmCrypto.encryptRsa(mobile, publicKeyPem);

      // 3. Generate OTP
      String? txnId;
      try {
        final result = await AbdmService.generateMobileOtp(
          encryptedMobile: encryptedMobile,
        );
        txnId = result['txnId'] as String?;
      } catch (_) {
        // Fallback for demo
        txnId = 'demo_txn';
      }
      
      if (txnId == null) throw Exception("No transaction ID returned");

      if (mounted) {
        Navigator.pushNamed(
          context, 
          '/login-otp', // Reusing OTP screen
          arguments: {
            'txnId': txnId,
            'publicKey': publicKeyPem,
            'flow': 'registration_mobile',
            'authMethod': 'Mobile OTP',
            'loginId': '+91 $mobile',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                  const TranslatedText('Create ABHA',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText('Mobile Number',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                    ),
                    const SizedBox(height: 12),
                    const TranslatedText('Enter your mobile number to create ABHA',
                      style: TextStyle(fontSize: 15, color: Color(0xFF9BA8BB)),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Enter mobile number',
                        prefixText: '+91 ',
                        prefixStyle: const TextStyle(color: Color(0xFF0D2240)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00A3A3)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                              color: _termsAgreed ? const Color(0xFF00A3A3) : Colors.white,
                            ),
                            child: _termsAgreed
                                ? const Center(
                              child: Icon(Icons.check, size: 14, color: Colors.white),
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
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: ElevatedButton(
                onPressed: (_mobileController.text.length == 10 && _termsAgreed && !_isLoading)
                    ? _handleContinue
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_mobileController.text.length == 10 && _termsAgreed)
                      ? const Color(0xFF00A3A3)
                      : const Color(0xFFD8DDE6),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : TranslatedText('Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _mobileController.text.length == 10 && _termsAgreed
                            ? Colors.white
                            : const Color(0xFF9BA8BB),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }
}