import 'package:flutter/material.dart';

import '../services/bhashini_translate_service.dart';
import 'app_language.dart';

class TranslatedText extends StatelessWidget {
  const TranslatedText(
    this.sourceText, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String sourceText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.selectedLanguage,
      builder: (context, language, _) {
        if (language == AppLanguage.defaultLanguage) {
          return Text(
            sourceText,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          );
        }

        return FutureBuilder<String>(
          future: BhashiniTranslateService.translateUiText(
            sourceText,
            targetLanguage: language,
          ),
          initialData: sourceText,
          builder: (context, snapshot) {
            final translated = snapshot.data ?? sourceText;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                translated,
                key: ValueKey<String>(translated),
                style: style,
                textAlign: textAlign,
                maxLines: maxLines,
                overflow: overflow,
              ),
            );
          },
        );
      },
    );
  }
}
