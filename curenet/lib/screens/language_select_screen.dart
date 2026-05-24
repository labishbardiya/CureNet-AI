import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../core/translated_text.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  String selectedLanguage = AppLanguage.selectedLanguage.value;

  final List<Map<String, String>> languages = [
    {'label': 'English', 'value': 'English', 'native': ''},
    {'label': 'हिन्दी', 'value': 'Hindi', 'native': 'Hindi'},
    {'label': 'বাংলা', 'value': 'Bengali', 'native': 'Bengali'},
    {'label': 'తెలుగు', 'value': 'Telugu', 'native': 'Telugu'},
    {'label': 'मराठी', 'value': 'Marathi', 'native': 'Marathi'},
    {'label': 'தமிழ்', 'value': 'Tamil', 'native': 'Tamil'},
    {'label': 'اردو', 'value': 'Urdu', 'native': 'Urdu'},
    {'label': 'ગુજરાતી', 'value': 'Gujarati', 'native': 'Gujarati'},
    {'label': 'ಕನ್ನಡ', 'value': 'Kannada', 'native': 'Kannada'},
    {'label': 'ଓଡ଼ିଆ', 'value': 'Odia', 'native': 'Odia'},
    {'label': 'മലയാളം', 'value': 'Malayalam', 'native': 'Malayalam'},
    {'label': 'ਪੰਜਾਬੀ', 'value': 'Punjabi', 'native': 'Punjabi'},
    {'label': 'অসমীয়া', 'value': 'Assamese', 'native': 'Assamese'},
    {'label': 'मैथिली', 'value': 'Maithili', 'native': 'Maithili'},
    {'label': 'संस्कृत', 'value': 'Sanskrit', 'native': 'Sanskrit'},
    {'label': 'नेपाली', 'value': 'Nepali', 'native': 'Nepali'},
    {'label': 'सिंधी', 'value': 'Sindhi', 'native': 'Sindhi'},
    {'label': 'कोंकणी', 'value': 'Konkani', 'native': 'Konkani'},
    {'label': 'डोगरी', 'value': 'Dogri', 'native': 'Dogri'},
    {'label': 'बड़ो', 'value': 'Bodo', 'native': 'Bodo'},
    {'label': 'মৈতৈলোন্', 'value': 'Manipuri', 'native': 'Manipuri'},
    {'label': 'کٲشُر', 'value': 'Kashmiri', 'native': 'Kashmiri'},
  ];

  void pickLanguage(String lang) {
    setState(() => selectedLanguage = AppLanguage.normalizeLanguage(lang));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header – exact v5
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
                  child: const Text(
                    '←',
                    style: TextStyle(fontSize: 26, color: Color(0xFF0D2240)),
                  ),
                ),
                const SizedBox(width: 14),
                const TranslatedText('Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D2240),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable language list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isSelected = lang['value'] == selectedLanguage;

                return GestureDetector(
                  onTap: () => pickLanguage(lang['value']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F7F7) : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(0xFFD8DDE6),
                          width: index == languages.length - 1 ? 0 : 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Radio dot
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB),
                              width: isSelected ? 3 : 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0D2240),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          lang['label']!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D2240),
                          ),
                        ),
                        if (lang['native']!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            lang['native']!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9BA8BB),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Continue button – exact v5 teal
          Padding(
            padding: const EdgeInsets.all(18),
            child: ElevatedButton(
              onPressed: () async {
                await AppLanguage.setLanguage(selectedLanguage);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A3A3),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const TranslatedText('Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}