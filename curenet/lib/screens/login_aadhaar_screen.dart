import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';
import '../services/abdm_service.dart';
import '../core/abdm_crypto.dart';

class LoginAadhaarScreen extends StatefulWidget {
  const LoginAadhaarScreen({super.key});

  @override
  State<LoginAadhaarScreen> createState() => _LoginAadhaarScreenState();
}

class _LoginAadhaarScreenState extends State<LoginAadhaarScreen> {
  final TextEditingController _aadhaarController = TextEditingController();
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
      // 1. Get Public Key
      final keyData = await AbdmService.getPublicKey();
      final publicKeyPem = keyData['publicKey'] as String?;
      if (publicKeyPem == null) throw Exception("Failed to retrieve encryption key");

      // 2. Encrypt Aadhaar
      final encryptedAadhaar = AbdmCrypto.encryptRsa(aadhaar, publicKeyPem);

      // 3. Request OTP for Login
      String? txnId;
      try {
        final result = await AbdmService.requestAadhaarOtp(
          encryptedAadhaar: encryptedAadhaar,
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
          '/login-otp', 
          arguments: {
            'txnId': txnId,
            'publicKey': publicKeyPem,
            'flow': 'login',
            'authMethod': 'Aadhaar OTP',
            'loginId': 'your Aadhaar-linked mobile',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Color(0xFF0D2240))),
                ),
                const SizedBox(width: 14),
                const TranslatedText("Aadhaar Number Login",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TranslatedText("Enter your 12-digit Aadhaar number",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleGetOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const TranslatedText("Get OTP →", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}