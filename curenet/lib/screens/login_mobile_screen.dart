import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';
import 'package:curenet/core/navigation_helper.dart';

class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({super.key});

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  final TextEditingController _mobileController = TextEditingController(text: "98765 43210");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    "←",
                    style: TextStyle(fontSize: 26, color: Color(0xFF0D2240)),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(
                        "Mobile Login",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                      ),
                      TranslatedText(
                        "Step 1 of 2",
                        style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
                      ),
                    ],
                  ),
                ),
                // Step pills
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A3A3),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          "1",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 2,
                      color: const Color(0xFFD8DDE6),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD8DDE6), width: 2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Big visual section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Phone illustration card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.phone_android,
                          size: 52,
                          color: Color(0xFFE07B39),
                        ),
                        const SizedBox(height: 10),
                        const TranslatedText(
                          "Enter your mobile number",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D2240)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const TranslatedText(
                          "We'll send a 6-digit OTP to verify",
                          style: TextStyle(fontSize: 13, color: Color(0xFF5A6880)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Mobile input with +91
                  const TranslatedText(
                    "Mobile Number",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00A3A3), width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Country code
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: const [
                              Icon(Icons.flag, size: 16, color: Color(0xFF0D2240)),
                              SizedBox(width: 6),
                              Text(
                                "+91",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFD8DDE6)),
                        Expanded(
                          child: TextField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "98765 43210",
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              counterText: "",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const TranslatedText(
                    "A 6-digit OTP will be sent to this number",
                    style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
                  ),

                  const SizedBox(height: 32),

                  // Get OTP Button
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return ElevatedButton(
                        onPressed: auth.status == AuthStatus.authenticating
                            ? null
                            : () async {
                                final mobile = _mobileController.text.replaceAll(' ', '');
                                if (mobile.length != 10) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
                                  );
                                  return;
                                }
                                await auth.loginWithMobile(mobile);
                                if (auth.status == AuthStatus.error) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(auth.error ?? 'An error occurred')),
                                  );
                                } else {
                                  Navigator.pushNamed(context, '/login-otp', arguments: {
                                    'txnId': auth.lastTxnId ?? '',
                                    'loginId': '+91 ${mobile.substring(0, 5)} ${mobile.substring(5)}',
                                    'authMethod': 'Mobile OTP',
                                    'flow': 'login',
                                    'publicKey': auth.lastPublicKey,
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A3A3),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: auth.status == AuthStatus.authenticating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const TranslatedText(
                                "Get OTP on Mobile",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Create ABHA Banner
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register-options'),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0D2240), Color(0xFF1A3A5C)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, size: 22, color: Colors.white),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "No ABHA yet? Create FREE",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                Text(
                                  "Create your free ABHA health ID",
                                  style: TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const Text("›", style: TextStyle(fontSize: 18, color: Colors.white54)),
                        ],
                      ),
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
}