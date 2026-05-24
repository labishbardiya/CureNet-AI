import 'package:flutter/material.dart';
import 'dart:async';
import '../core/app_language.dart';
import '../core/translated_text.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int currentSlide = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
    _checkAuth();
  }

  void _checkAuth() async {
    // Wait for a second to show the splash
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      _carouselTimer?.cancel();
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  void _startAutoSlide() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          currentSlide = (currentSlide + 1) % slides.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    super.dispose();
  }

  final List<Map<String, dynamic>> slides = [
    {
      "icon": Icons.eco,
      "title": "Your Health,\nOne Place",
      "desc": "All your medical records from every hospital and clinic — safe, secure, always with you."
    },
    {
      "icon": Icons.smart_toy,
      "title": "ABHAy\nAI Assistant",
      "desc": "Ask questions about your health in Hindi or English. Get simple, clear answers anytime."
    },
    {
      "icon": Icons.qr_code_scanner,
      "title": "Share with\nDoctors",
      "desc": "Show your records via QR code. You decide what doctors see. Always in control."
    },
    {
      "icon": Icons.shield,
      "title": "Zero-Knowledge\nSecurity",
      "desc": "Your data is encrypted and DPDP Act 2023 compliant. Only you can grant access."
    },
    {
      "icon": Icons.language,
      "title": "Works Offline &\nIn 22 Languages",
      "desc": "Access your records even without internet. Available in Hindi, Tamil, Telugu and 19 more."
    },
  ];

  @override
  Widget build(BuildContext context) {
    final slide = slides[currentSlide];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header – exact v5 (logo + language picker)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 44, 26, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD8DDE6), width: 1.5),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/curenet_logo.png',
                            width: 28,
                            height: 28,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.health_and_safety, size: 28, color: Color(0xFFD32F2F));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "CureNet",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D2240),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  // Language picker (opens lang-select)
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/language-select'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        border: Border.all(color: const Color(0xFFD8DDE6), width: 2),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: ValueListenableBuilder<String>(
                        valueListenable: AppLanguage.selectedLanguage,
                        builder: (context, language, _) {
                          return Row(
                            children: [
                              const Icon(Icons.flag, size: 15, color: Color(0xFF0D2240)),
                              const SizedBox(width: 6),
                              Text(
                                language,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "▼",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9BA8BB),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Big illustration circle (v5 exact)
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F7),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C4C4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      slide["icon"] as IconData,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Title & Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  TranslatedText(
                    slide["title"],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      color: Color(0xFF0D2240),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TranslatedText(
                    slide["desc"],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF5A6880),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Slide dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentSlide == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentSlide == i ? const Color(0xFF00A3A3) : const Color(0xFFD8DDE6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {
                  _carouselTimer?.cancel();
                  Navigator.pushNamed(context, '/login-options');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2240),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const TranslatedText(
                  "Get Started",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}