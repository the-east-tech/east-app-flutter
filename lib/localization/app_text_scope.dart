import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_text.dart';

class AppTextScope extends InheritedWidget {
  final AppLanguage language;
  final Map<String, String> contentTranslations;
  final AppText text;

  AppTextScope({
    super.key,
    required this.language,
    this.contentTranslations = const <String, String>{},
    required super.child,
  }) : text = AppText(
          language,
          contentTranslations: contentTranslations,
        );

  static AppText of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppTextScope>();
    return scope?.text ?? const AppText(AppLanguage.english);
  }

  @override
  bool updateShouldNotify(AppTextScope oldWidget) {
    return oldWidget.language != language ||
        oldWidget.contentTranslations != contentTranslations;
  }
}
