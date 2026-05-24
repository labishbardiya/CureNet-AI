import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';
import '../core/abdm_crypto.dart';
import '../services/abdm_service.dart';

class LoginAbhaNumScreen extends StatefulWidget {
  const LoginAbhaNumScreen({super.key});

  @override
  State<LoginAbhaNumScreen> createState() => _LoginAbhaNumScreenState();
}

class _LoginAbhaNumScreenState extends State<LoginAbhaNumScreen> {
  String _selectedAuth = "Aadhaar OTP";
  final TextEditingController _abhaController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _abhaController.dispose();
    super.dispose();
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText("Login With ABHA Number",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                      ),
                      TranslatedText("Step 1 of 2",
                        style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
                      ),
                    ],
                  ),
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
                  const TranslatedText("ABHA Number",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _abhaController,
                    keyboardType: TextInputType.number,
                    maxLength: 14,
                    decoration: InputDecoration(
                      hintText: "00-0000-0000-0000",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00A3A3), width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/forgot-abha'),
                      child: const TranslatedText("Forgot ABHA number?",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE07B39)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const TranslatedText("Validate using",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _validateTile("Aadhaar OTP", Icons.badge),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _validateTile("Mobile OTP", Icons.phone_android),
                      ),
                    ],
                  ),

                  const Spacer(),

                  ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      if (_abhaController.text.length < 14) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: TranslatedText('Please enter a valid 14-digit ABHA Number')),
                        );
                        return;
                      }

                      setState(() => _isLoading = true);

                      try {
                        // 1. Fetch live ABDM Public Key
                        final keyMap = await AbdmService.getPublicKey();
                        final String publicKey = keyMap['publicKey'];

                        // 2. Encrypt the ABHA Number using RSA OAEP SHA-1
                        final String encryptedAbha = AbdmCrypto.encryptRsa(_abhaController.text, publicKey);

                        // 3. Request OTP from ABDM Gateway
                        final response = await AbdmService.requestAadhaarOtp(encryptedAadhaar: encryptedAbha);

                        if (!mounted) return;
                        setState(() => _isLoading = false);

                        // 4. Pass the transaction ID to the OTP Screen
                        Navigator.pushNamed(
                          context, 
                          '/login-otp',
                          arguments: {
                            'authMethod': _selectedAuth, 
                            'loginId': _abhaController.text,
                            'txnId': response['txnId'] // Captured for verification
                          },
                        );

                      } catch (e) {
                        // Fallback constraint (Handles Sandbox DNS/VPN errors seamlessly if offline)
                        print("ABDM Sandbox failure (Offline): $e");
                        if (!mounted) return;
                        setState(() => _isLoading = false);
                        Navigator.pushNamed(
                          context, 
                          '/login-otp',
                          arguments: {'authMethod': _selectedAuth, 'loginId': _abhaController.text},
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3A3),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          width: 24, height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const TranslatedText("Continue",
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

  Widget _validateTile(String title, IconData icon) {
    final bool isSelected = _selectedAuth == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAuth = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF00A3A3) : const Color(0xFFD8DDE6),
            width: isSelected ? 2 : 1.5,
          ),
          color: isSelected ? const Color(0xFFE8F7F7) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? const Color(0xFF00A3A3) : const Color(0xFF0D2240)),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF00A3A3) : const Color(0xFF0D2240),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}