enum AppLanguage {
  english,
  chinese,
  myanmar,
}

extension AppLanguageLabel on AppLanguage {
  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.myanmar:
        return 'မြန်မာ';
      case AppLanguage.chinese:
        return '中文';
    }
  }

  String get shortLabel {
    switch (this) {
      case AppLanguage.english:
        return 'EN';
      case AppLanguage.myanmar:
        return 'MY';
      case AppLanguage.chinese:
        return '中';
    }
  }
}
