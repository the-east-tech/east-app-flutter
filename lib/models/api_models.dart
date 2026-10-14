import 'dart:typed_data';

class FlowPage<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  const FlowPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory FlowPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) mapper,
  ) {
    return FlowPage<T>(
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

class FlowCsvFile {
  final String fileName;
  final Uint8List bytes;

  const FlowCsvFile({required this.fileName, required this.bytes});
}

class FlowCsvPreview {
  final int totalRows;
  final int readyRows;
  final int duplicateRows;
  final int invalidRows;
  final List<String> errors;

  const FlowCsvPreview({
    required this.totalRows,
    required this.readyRows,
    required this.duplicateRows,
    required this.invalidRows,
    required this.errors,
  });

  bool get canImport => readyRows > 0 && invalidRows == 0;

  factory FlowCsvPreview.fromJson(Map<String, dynamic> json) {
    return FlowCsvPreview(
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

class FlowCsvImportResult {
  final int importedRows;
  final int skippedDuplicateRows;

  const FlowCsvImportResult({
    required this.importedRows,
    required this.skippedDuplicateRows,
  });

  factory FlowCsvImportResult.fromJson(Map<String, dynamic> json) {
    return FlowCsvImportResult(
      importedRows: (json['importedRows'] as num? ?? 0).toInt(),
      skippedDuplicateRows:
          (json['skippedDuplicateRows'] as num? ?? 0).toInt(),
    );
  }
}

class FlowDeletionDependency {
  final String code;
  final String label;
  final int count;
  final String location;

  const FlowDeletionDependency({
    required this.code,
    required this.label,
    required this.count,
    required this.location,
  });

  factory FlowDeletionDependency.fromJson(Map<String, dynamic> json) {
    return FlowDeletionDependency(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      count: (json['count'] as num? ?? 0).toInt(),
      location: json['location'] as String? ?? '',
    );
  }
}

class FlowDeletionPreview {
  final bool deletable;
  final List<FlowDeletionDependency> dependencies;

  const FlowDeletionPreview({
    required this.deletable,
    required this.dependencies,
  });

  factory FlowDeletionPreview.fromJson(Map<String, dynamic> json) {
    return FlowDeletionPreview(
      deletable: json['deletable'] as bool? ?? false,
      dependencies: (json['dependencies'] as List<dynamic>? ?? const [])
          .map(
            (item) => FlowDeletionDependency.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  factory FlowDeletionPreview.merge(
    Iterable<FlowDeletionPreview> previews,
  ) {
    final merged = <String, FlowDeletionDependency>{};
    for (final preview in previews) {
      for (final dependency in preview.dependencies) {
        final key = '${dependency.code}:${dependency.location}';
        final existing = merged[key];
        merged[key] = FlowDeletionDependency(
          code: dependency.code,
          label: dependency.label,
          count: (existing?.count ?? 0) + dependency.count,
          location: dependency.location,
        );
      }
    }
    final dependencies = merged.values.toList(growable: false);
    return FlowDeletionPreview(
      deletable: dependencies.isEmpty,
      dependencies: dependencies,
    );
  }
}
