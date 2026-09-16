import 'dart:typed_data';

class EastAppPage<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  const EastAppPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory EastAppPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) mapper,
  ) {
    return EastAppPage<T>(
      content: (json['content'] as List<dynamic>? ?? const [])
          .map((item) => mapper(item as Map<String, dynamic>))
          .toList(growable: false),
      page: (json['page'] as num).toInt(),
      size: (json['size'] as num).toInt(),
      totalElements: (json['totalElements'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      first: json['first'] as bool,
      last: json['last'] as bool,
    );
  }
}

String? formatApiDate(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class EastAppCsvFile {
  final String fileName;
  final Uint8List bytes;

  const EastAppCsvFile({required this.fileName, required this.bytes});
}

class EastAppCsvPreview {
  final String format;
  final int formatVersion;
  final int totalRows;
  final int readyRows;
  final int duplicateRows;
  final int invalidRows;
  final List<String> errors;

  const EastAppCsvPreview({
    required this.format,
    required this.formatVersion,
    required this.totalRows,
    required this.readyRows,
    required this.duplicateRows,
    required this.invalidRows,
    required this.errors,
  });

  bool get canImport => readyRows > 0 && invalidRows == 0;

  factory EastAppCsvPreview.fromJson(Map<String, dynamic> json) {
    return EastAppCsvPreview(
      format: json['format'] as String? ?? '',
      formatVersion: (json['formatVersion'] as num? ?? 0).toInt(),
      totalRows: (json['totalRows'] as num? ?? 0).toInt(),
      readyRows: (json['readyRows'] as num? ?? 0).toInt(),
      duplicateRows: (json['duplicateRows'] as num? ?? 0).toInt(),
      invalidRows: (json['invalidRows'] as num? ?? 0).toInt(),
      errors: (json['errors'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class EastAppCsvImportResult {
  final int importedRows;
  final int skippedDuplicateRows;

  const EastAppCsvImportResult({
    required this.importedRows,
    required this.skippedDuplicateRows,
  });

  factory EastAppCsvImportResult.fromJson(Map<String, dynamic> json) {
    return EastAppCsvImportResult(
      importedRows: (json['importedRows'] as num? ?? 0).toInt(),
      skippedDuplicateRows:
          (json['skippedDuplicateRows'] as num? ?? 0).toInt(),
    );
  }
}
