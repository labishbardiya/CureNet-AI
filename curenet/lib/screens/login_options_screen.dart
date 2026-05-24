import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../core/translated_text.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../services/secure_storage_service.dart';

class LoginOptionsScreen extends StatelessWidget {
  const LoginOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          // Top gradient section with logo
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8EDF5), Color(0xFFD5DCE9)],
                ),
              ),
              child: Stack(
                children: [
                  // Language picker (top right)
                  Positioned(
                    top: 46,
                    right: 18,
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/language-select'),
                      child: ValueListenableBuilder<String>(
                        valueListenable: AppLanguage.selectedLanguage,
                        builder: (context, language, _) {
                          return Row(
                            children: [
                              const Icon(Icons.language, size: 18, color: Color(0xFF0D2240)),
                              const SizedBox(width: 6),
                              Text(
                                language,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D2240),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Big centered logo card
                  Center(
                    child: Container(
                      width: 130,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2240),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/curenet_logo.png',
                                width: 32,
                                height: 32,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.health_and_safety,
                                    size: 32,
                                    color: Color(0xFF0D2240),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "CureNet",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            "ABHA",
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF00C4C4),
                              fontWeight: FontWeight.w700,
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

          // Bottom white sheet
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 32,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const TranslatedText(
                  "Login",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D2240),
                  ),
                ),
                const SizedBox(height: 4),
                const TranslatedText(
                  "Choose how you want to login",
                  style: TextStyle(fontSize: 13, color: Color(0xFF5A6880)),
                ),
                const SizedBox(height: 20),

                // Mobile Option
                _buildOptionCard(
                  context,
                  icon: Icons.phone_android,
                  iconColor: const Color(0xFFE07B39),
                  title: "Mobile Number",
                  onTap: () => Navigator.pushNamed(context, '/login-mobile'),
                ),

                const SizedBox(height: 10),

                // Aadhaar Option
                _buildOptionCard(
                  context,
                  icon: Icons.badge,
                  iconColor: const Color(0xFF00A3A3),
                  title: "Aadhaar Card",
                  onTap: () => Navigator.pushNamed(context, '/login-aadhaar'),
                ),

                const SizedBox(height: 10),


                const SizedBox(height: 16),

                // Smaller ABHA tiles
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallTile(
                        icon: Icons.pin,
                        label: "ABHA Number",
                        onTap: () => Navigator.pushNamed(context, '/login-abha-num'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSmallTile(
                        icon: Icons.perm_identity,
                        label: "ABHA Address",
                        onTap: () => Navigator.pushNamed(context, '/login-abha-addr'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Create ABHA Banner
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/register-options'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE07B39), Color(0xFFC9601A)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Center(
                            child: Icon(Icons.add, size: 22, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                "No ABHA? Create FREE",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              TranslatedText(
                                "Get your free digital health ID today",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          "›",
                          style: TextStyle(fontSize: 22, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD8DDE6), width: 2),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(icon, size: 26, color: iconColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TranslatedText(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2240),
                ),
              ),
            ),
            const Text(
              "›",
              style: TextStyle(fontSize: 22, color: Color(0xFF9BA8BB)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD8DDE6), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF0D2240)),
            const SizedBox(height: 6),
            TranslatedText(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D2240),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}