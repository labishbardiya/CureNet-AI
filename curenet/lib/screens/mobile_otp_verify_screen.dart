import 'package:flutter/material.dart';
import 'dart:async';
import '../core/theme.dart';
import '../core/translated_text.dart';
import 'package:flutter/services.dart';

class MobileOtpVerifyScreen extends StatefulWidget {
  const MobileOtpVerifyScreen({super.key});

  @override
  State<MobileOtpVerifyScreen> createState() => _MobileOtpVerifyScreenState();
}

class _MobileOtpVerifyScreenState extends State<MobileOtpVerifyScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes;
  int _timerSeconds = 60;
  bool _resendEnabled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(6, (index) => FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_otpControllers[index].text.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
            _otpControllers[index - 1].clear();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    ));
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
        setState(() => _resendEnabled = true);
      }
    });
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
                  const TranslatedText('Verify Mobile',
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
                    const TranslatedText('Enter OTP sent to\n+91 9876543210',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
                    ),
                    const SizedBox(height: 12),
                    const TranslatedText('OTP will expire in',
                      style: TextStyle(fontSize: 15, color: Color(0xFF9BA8BB)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_timerSeconds sec',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _timerSeconds < 10 ? Colors.red : const Color(0xFF00A3A3),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) => SizedBox(
                        width: 48,
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF00A3A3), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            if (value.length == 1 && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            if (_otpControllers.every((c) => c.text.length == 1)) {
                              Navigator.pushNamed(context, '/register-mobile-details');
                            }
                          },
                        ),
                      )),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _resendEnabled ? () {
                        setState(() {
                          _timerSeconds = 60;
                          _resendEnabled = false;
                        });
                        _startTimer();
                      } : null,
                      child: Text(
                        _resendEnabled ? 'Resend OTP' : 'Resend OTP in $_timerSeconds sec',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _resendEnabled ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB),
                        ),
                      ),
                    ),
                  ],
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
    _timer?.cancel();
    _otpControllers.forEach((c) => c.dispose());
    _focusNodes.forEach((f) => f.dispose());
    super.dispose();
  }
}