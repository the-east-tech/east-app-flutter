enum ContentLanguage {
  english('ENGLISH', 'English'),
  chinese('CHINESE', 'Chinese'),
  myanmar('MYANMAR', 'Myanmar');

  const ContentLanguage(this.apiValue, this.label);

  final String apiValue;
  final String label;

  bool matches(String value) {
    final hasChinese = RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]')
        .hasMatch(value);
    final hasMyanmar = RegExp(r'[\u1000-\u109f\ua9e0-\ua9ff\uaa60-\uaa7f]')
        .hasMatch(value);
    switch (this) {
      case ContentLanguage.english:
        return !hasChinese && !hasMyanmar && RegExp(r'[A-Za-z]').hasMatch(value);
      case ContentLanguage.chinese:
        return hasChinese;
      case ContentLanguage.myanmar:
        return hasMyanmar;
    }
  }
}

enum TranslationDirection {
  englishToMyanmar(ContentLanguage.english, ContentLanguage.myanmar),
  englishToChinese(ContentLanguage.english, ContentLanguage.chinese),
  chineseToEnglish(ContentLanguage.chinese, ContentLanguage.english),
  chineseToMyanmar(ContentLanguage.chinese, ContentLanguage.myanmar),
  myanmarToEnglish(ContentLanguage.myanmar, ContentLanguage.english),
  myanmarToChinese(ContentLanguage.myanmar, ContentLanguage.chinese);

  const TranslationDirection(this.source, this.target);

  final ContentLanguage source;
  final ContentLanguage target;

  String get label => '${source.label} → ${target.label}';
}

class TranslationPreview {
  final int uniqueTextCount;
  final int selectedCacheHits;
  final int selectedCacheMisses;
  final int companionCacheHits;
  final int companionCacheMisses;
  final int providerRequestsIfConfirmed;
  final bool providerAvailable;

  const TranslationPreview({
    required this.uniqueTextCount,
    required this.selectedCacheHits,
    required this.selectedCacheMisses,
    required this.companionCacheHits,
    required this.companionCacheMisses,
    required this.providerRequestsIfConfirmed,
    required this.providerAvailable,
  });

  int get storedTranslations => selectedCacheHits + companionCacheHits;

  bool get canApply => providerAvailable || selectedCacheMisses == 0;

  factory TranslationPreview.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;

    return TranslationPreview(
      uniqueTextCount: count('uniqueTextCount'),
      selectedCacheHits: count('selectedCacheHits'),
      selectedCacheMisses: count('selectedCacheMisses'),
      companionCacheHits: count('companionCacheHits'),
      companionCacheMisses: count('companionCacheMisses'),
      providerRequestsIfConfirmed: count('providerRequestsIfConfirmed'),
      providerAvailable: json['providerAvailable'] as bool? ?? false,
    );
  }

  TranslationPreview merge(TranslationPreview other) {
    return TranslationPreview(
      uniqueTextCount: uniqueTextCount + other.uniqueTextCount,
      selectedCacheHits: selectedCacheHits + other.selectedCacheHits,
      selectedCacheMisses: selectedCacheMisses + other.selectedCacheMisses,
      companionCacheHits: companionCacheHits + other.companionCacheHits,
      companionCacheMisses:
          companionCacheMisses + other.companionCacheMisses,
      providerRequestsIfConfirmed:
          providerRequestsIfConfirmed + other.providerRequestsIfConfirmed,
      providerAvailable: providerAvailable && other.providerAvailable,
    );
  }

  static const empty = TranslationPreview(
    uniqueTextCount: 0,
    selectedCacheHits: 0,
    selectedCacheMisses: 0,
    companionCacheHits: 0,
    companionCacheMisses: 0,
    providerRequestsIfConfirmed: 0,
    providerAvailable: true,
  );
}

String normaliseContentText(String value) {
  return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
}
