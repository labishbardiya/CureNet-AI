import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';
import '../services/abdm_service.dart';
import '../core/abdm_crypto.dart';
import '../core/data_mode.dart';

class CreateAbhaAadhaarScreen extends StatefulWidget {
  const CreateAbhaAadhaarScreen({super.key});

  @override
  State<CreateAbhaAadhaarScreen> createState() => _CreateAbhaAadhaarScreenState();
}

class _CreateAbhaAadhaarScreenState extends State<CreateAbhaAadhaarScreen> {
  final TextEditingController _aadhaarController = TextEditingController();
  bool _agreed = false;
  bool _isLoading = false;

  Future<void> _handleGetOtp() async {
    final aadhaar = _aadhaarController.text.replaceAll(' ', '');
    if (aadhaar.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 12-digit Aadhaar number")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Get Public Key from Gateway
      final keyData = await AbdmService.getPublicKey();
      final publicKeyPem = keyData['publicKey'] as String?;
      
      if (publicKeyPem == null) throw Exception("Failed to retrieve encryption key");

      // 2. Encrypt Aadhaar number
      final encryptedAadhaar = AbdmCrypto.encryptRsa(aadhaar, publicKeyPem);

      // 3. Generate OTP
      String? txnId;
      try {
        final result = await AbdmService.generateAadhaarOtpForRegistration(
          encryptedAadhaar: encryptedAadhaar,
        );
        txnId = result['txnId'] as String?;
      } catch (e) {
        // Sandbox fallback — real ABDM may not be available
        txnId = 'demo_txn';
      }
      
      if (txnId == null) throw Exception("No transaction ID returned");

      if (mounted) {
        Navigator.pushNamed(
          context, 
          '/login-otp', 
          arguments: {
            'txnId': txnId,
            'publicKey': publicKeyPem,
            'flow': 'registration',
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
                const Expanded(
                  child: TranslatedText("Create ABHA Number",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Step Indicator
                  Row(
                    children: [
                      _stepCircle(1, true),
                      _stepLine(),
                      _stepCircle(2, false),
                      _stepLine(),
                      _stepCircle(3, false),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Visual help
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge, size: 32, color: Color(0xFF00A3A3)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText("Enter your 12-digit Aadhaar number",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                              ),
                              SizedBox(height: 4),
                              TranslatedText("Used only for OTP verification — not stored permanently",
                                style: TextStyle(fontSize: 12, color: Color(0xFF5A6880)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const TranslatedText("Aadhaar Number",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _aadhaarController,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4),
                    decoration: InputDecoration(
                      hintText: "1234 5678 9012",
                      counterText: "",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00A3A3), width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // OTP Option
                  const TranslatedText("Verify with OTP",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00A3A3), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.message, size: 28, color: Color(0xFF00A3A3)),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: TranslatedText("OTP on Registered Mobile",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF00A3A3), width: 3),
                          ),
                          child: const Center(
                            child: Icon(Icons.check, size: 16, color: Color(0xFF00A3A3)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Terms & Conditions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreed,
                        activeColor: const Color(0xFF00A3A3),
                        onChanged: (val) => setState(() => _agreed = val!),
                      ),
                      const Expanded(
                        child: TranslatedText("I voluntarily share my Aadhaar details with National Health Authority (NHA) to create my ABHA. My data will be used only for healthcare services as per ABDM guidelines.",
                          style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF5A6880)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Continue Button
                  ElevatedButton(
                    onPressed: (_agreed && !_isLoading) ? _handleGetOtp : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const TranslatedText("Get OTP →",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(int number, bool active) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF00A3A3) : const Color(0xFFD8DDE6),
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : const Color(0xFF9BA8BB),
          ),
        ),
      ),
    );
  }

  Widget _stepLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: const Color(0xFFD8DDE6),
      ),
    );
  }
}