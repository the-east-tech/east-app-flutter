part of 'stock_screen.dart';

List<SupplierProfile> _sortSuppliersAlphabetically(Iterable<SupplierProfile> source) {
  final items = source.toList();
  items.sort((a, b) {
    final result = a.supplierName.toLowerCase().compareTo(b.supplierName.toLowerCase());
    if (result != 0) return result;
    return a.id.compareTo(b.id);
  });
  return items;
}

Future<T?> showStockBottomSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext sheetContext) builder,
  double maxHeightFactor = 0.9,
}) {
  final mediaScope = context.getInheritedWidgetOfExactType<_StockMediaScope>();
  final textScope = context.getInheritedWidgetOfExactType<AppTextScope>();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
      Widget sheet = Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * maxHeightFactor,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: builder(sheetContext),
      );
      if (mediaScope != null) {
        sheet = _StockMediaScope(
          api: mediaScope.api,
          loadThumbnail: mediaScope.loadThumbnail,
          loadReceivingPhoto: mediaScope.loadReceivingPhoto,
          child: sheet,
        );
      }
      if (textScope != null) {
        sheet = AppTextScope(
          language: textScope.language,
          contentTranslations: textScope.contentTranslations,
          child: sheet,
        );
      }
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: sheet,
        ),
      );
    },
  );
}

Widget stockBottomSheetHandle() {
  return Center(
    child: Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFD8DEE8),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

Future<bool> runStockRequest(
  BuildContext context,
  Future<void> Function() request,
) async {
  try {
    await request();
    return true;
  } on EastAppApiException catch (_) {
    return false;
  }
}

class _DataRefreshBar extends StatefulWidget {
  final DateTime? updatedAt;
  final Future<void> Function() onRefresh;

  const _DataRefreshBar({required this.updatedAt, required this.onRefresh});

  @override
  State<_DataRefreshBar> createState() => _DataRefreshBarState();
}

class _DataRefreshBarState extends State<_DataRefreshBar> {
  bool refreshing = false;

  Future<void> refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  String get updatedText {
    final value = widget.updatedAt;
    if (value == null) return 'Not loaded';
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Last updated ${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Material(
      color: const Color(0xFFF6F8FC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Row(
          children: [
            const Icon(Icons.storage_rounded, size: 18, color: AppColours.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.t(updatedText),
                style: const TextStyle(
                  color: AppColours.textMuted,
                  fontSize: AppTextSize.s12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: refreshing ? null : refresh,
              icon: refreshing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              label: Text(text.t('Refresh')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRefreshShell extends StatelessWidget {
  final DateTime? updatedAt;
  final Future<void> Function() onRefresh;
  final Widget child;

  const _DataRefreshShell({
    required this.updatedAt,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DataRefreshBar(updatedAt: updatedAt, onRefresh: onRefresh),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _StockMediaScope extends InheritedWidget {
  final EastAppApi api;
  final Future<Uint8List> Function(String storageKey) loadThumbnail;
  final Future<Uint8List> Function(String storageKey) loadReceivingPhoto;

  const _StockMediaScope({
    required this.api,
    required this.loadThumbnail,
    required this.loadReceivingPhoto,
    required super.child,
  });

  static _StockMediaScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_StockMediaScope>();
    assert(scope != null, 'Stock media scope is missing.');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant _StockMediaScope oldWidget) {
    return api != oldWidget.api ||
        loadThumbnail != oldWidget.loadThumbnail ||
        loadReceivingPhoto != oldWidget.loadReceivingPhoto;
  }
}
