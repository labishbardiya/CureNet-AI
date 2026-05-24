import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../core/theme.dart';
import '../core/translated_text.dart';
import 'package:flutter/services.dart';
import 'package:curenet/core/navigation_helper.dart';

class LoginOtpScreen extends StatefulWidget {
  const LoginOtpScreen({super.key});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes;
  String _otp = '';
  int _timerSeconds = 30;
  Timer? _timer;
  bool _showError = false;
  bool _isLoading = false;
  String? _txnId;
  String? _loginId;
  String? _authMethod;
  String? _flow;
  String? _publicKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _txnId == null) {
      _authMethod = args['authMethod'] as String? ?? (args['flow'] == 'registration' ? 'Aadhaar OTP' : 'Mobile OTP');
      _loginId = args['loginId'] as String? ?? (args['flow'] == 'registration' ? 'your Aadhaar-linked mobile' : '+91 98765 43210');
      _txnId = args['txnId'] as String?;
      _flow = args['flow'] as String?;
      _publicKey = args['publicKey'] as String?;
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(6, (index) => FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_controllers[index].text.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].clear();
            _onOtpChanged(index - 1, '');
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    ));
    _startTimer();
    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    _timerSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onOtpChanged(int index, String value) {
    setState(() {
      _otp = _controllers.map((c) => c.text).join();
      _showError = false;
    });

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.verifyOtp(
        _txnId ?? 'dummy_txn', 
        _otp, 
        flow: _flow ?? 'login',
        publicKey: _publicKey,
      );

      if (auth.status == AuthStatus.authenticated) {
        _timer?.cancel();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showError = true;
      });
      // Clear on error
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        setState(() => _showError = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
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
                TranslatedText(
                  "Enter OTP",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Illustration
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.mail, size: 48, color: Color(0xFF00A3A3)),
                    ),
                  ),

                  const SizedBox(height: 24),
                  TranslatedText(
                    "6-digit ${_authMethod ?? 'Mobile OTP'} sent to",
                    style: const TextStyle(fontSize: 13, color: Color(0xFF5A6880)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _loginId ?? '+91 98765 43210',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                  ),

                  const SizedBox(height: 32),

                  // OTP Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 46,
                        height: 54,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _controllers[index].text.isNotEmpty
                                ? const Color(0xFF00A3A3)
                                : const Color(0xFFD8DDE6),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          onChanged: (val) => _onOtpChanged(index, val),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 12),

                  // Timer & Resend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const TranslatedText("Resend in: ", style: TextStyle(fontSize: 12, color: Color(0xFF9BA8BB))),
                      Text(
                        "${_timerSeconds}s",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF22A36A)),
                      ),
                      const SizedBox(width: 20),
                      if (_timerSeconds == 0)
                        GestureDetector(
                          onTap: () {
                            _startTimer();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("OTP resent"), backgroundColor: Color(0xFF00A3A3)),
                            );
                          },
                          child: const TranslatedText(
                            "Resend OTP",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00A3A3)),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Error message
                  if (_showError)
                    const TranslatedText(
                      "Incorrect OTP. Please try again.",
                      style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                    ),

                  const SizedBox(height: 32),

                  // Verify Button
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return ElevatedButton(
                        onPressed: (_otp.length == 6 && auth.status != AuthStatus.authenticating) ? _verifyOtp : null,
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
                                "Verify OTP →",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  const TranslatedText(
                    "Demo OTP: 123456",
                    style: TextStyle(fontSize: 11, color: Color(0xFF9BA8BB)),
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