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

class EastAppDeletionDependency {
  final String code;
  final String label;
  final int count;
  final String location;

  const EastAppDeletionDependency({
    required this.code,
    required this.label,
    required this.count,
    required this.location,
  });

  factory EastAppDeletionDependency.fromJson(Map<String, dynamic> json) {
    return EastAppDeletionDependency(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      count: (json['count'] as num? ?? 0).toInt(),
      location: json['location'] as String? ?? '',
    );
  }
}

class EastAppDeletionPreview {
  final bool deletable;
  final List<EastAppDeletionDependency> dependencies;

  const EastAppDeletionPreview({
    required this.deletable,
    required this.dependencies,
  });

  factory EastAppDeletionPreview.fromJson(Map<String, dynamic> json) {
    return EastAppDeletionPreview(
      deletable: json['deletable'] as bool? ?? false,
      dependencies: (json['dependencies'] as List<dynamic>? ?? const [])
          .map(
            (item) => EastAppDeletionDependency.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  factory EastAppDeletionPreview.merge(
    Iterable<EastAppDeletionPreview> previews,
  ) {
    final merged = <String, EastAppDeletionDependency>{};
    for (final preview in previews) {
      for (final dependency in preview.dependencies) {
        final key = '${dependency.code}:${dependency.location}';
        final existing = merged[key];
        merged[key] = EastAppDeletionDependency(
          code: dependency.code,
          label: dependency.label,
          count: (existing?.count ?? 0) + dependency.count,
          location: dependency.location,
        );
      }
    }
    final dependencies = merged.values.toList(growable: false);
    return EastAppDeletionPreview(
      deletable: dependencies.isEmpty,
      dependencies: dependencies,
    );
  }
}
