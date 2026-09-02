part of 'stock_screen.dart';

class _ReceivingPhotoImage extends StatelessWidget {
  final String storageKey;
  final BoxFit fit;
  final Widget fallback;
  final double? width;
  final double? height;

  const _ReceivingPhotoImage({
    required this.storageKey,
    required this.fit,
    required this.fallback,
    this.width,
    this.height,
  });

  bool get hasStoredPhoto {
    final value = storageKey.trim().toLowerCase();
    return value.endsWith('.jpg') || value.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    if (!hasStoredPhoto) return fallback;
    final scope = _StockMediaScope.of(context);
    return FutureBuilder<Uint8List>(
      future: scope.loadReceivingPhoto(storageKey.trim()),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return fallback;
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }
}

class _ReceivingGoodsThumb extends StatelessWidget {
  final StockReceivingRecord record;
  final double size;
  final Color conditionColour;

  const _ReceivingGoodsThumb({required this.record, required this.size, required this.conditionColour});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: conditionColour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: conditionColour.withValues(alpha: 0.42)),
      ),
      child: Center(child: Icon(Icons.photo_camera_outlined, color: conditionColour, size: size * 0.46)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: _ReceivingPhotoImage(
        storageKey: record.goodsPhotoName,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}

class _CountReviewPhotoPreview extends StatelessWidget {
  final StockSku sku;
  final VoidCallback onTap;

  const _CountReviewPhotoPreview({required this.sku, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            SizedBox(width: double.infinity, child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _SkuPhotoThumb(sku: sku, size: 118))),
            Positioned(right: 8, bottom: 8, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.58), borderRadius: BorderRadius.circular(999)), child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16))),
          ]),
          const SizedBox(height: 7),
          Text(text.t('SKU Photo'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.textMuted, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ReviewPhotoGrid extends StatelessWidget {
  final StockReceivingRecord record;
  final Color conditionColour;
  const _ReviewPhotoGrid({required this.record, required this.conditionColour});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Row(children: [
      Expanded(child: _ReviewPhotoPreview(label: text.t('Goods Received'), record: record, conditionColour: conditionColour, isInvoice: false)),
      const SizedBox(width: 10),
      Expanded(child: _ReviewPhotoPreview(label: text.t('Invoice'), record: record, conditionColour: AppColours.blue, isInvoice: true)),
    ]);
  }
}

class _ReviewPhotoPreview extends StatelessWidget {
  final String label;
  final StockReceivingRecord record;
  final Color conditionColour;
  final bool isInvoice;

  const _ReviewPhotoPreview({required this.label, required this.record, required this.conditionColour, required this.isInvoice});

  String get storageKey => isInvoice ? record.invoicePhotoName : record.goodsPhotoName;

  Widget fallback({double? height}) => Container(
    height: height,
    color: conditionColour.withValues(alpha: 0.10),
    alignment: Alignment.center,
    child: Icon(isInvoice ? Icons.receipt_long_outlined : Icons.photo_camera_outlined, color: conditionColour, size: 34),
  );

  void showZoom(BuildContext context) {
    showStockBottomSheet<void>(
      context,
      maxHeightFactor: 0.92,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stockBottomSheetHandle(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: AppTextSize.s22, fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 12),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: InteractiveViewer(minScale: 1, maxScale: 4, child: _ReceivingPhotoImage(storageKey: storageKey, width: double.infinity, height: double.infinity, fit: BoxFit.contain, fallback: fallback())))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewFallback = Container(
      height: 118,
      decoration: BoxDecoration(color: conditionColour.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: conditionColour.withValues(alpha: 0.34))),
      child: Icon(isInvoice ? Icons.receipt_long_outlined : Icons.photo_camera_outlined, color: conditionColour, size: 34),
    );
    return Pressable(
      onTap: () => showZoom(context),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: _ReceivingPhotoImage(storageKey: storageKey, height: 118, width: double.infinity, fit: BoxFit.cover, fallback: previewFallback)),
            Positioned(right: 8, bottom: 8, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.58), borderRadius: BorderRadius.circular(999)), child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16))),
          ]),
          const SizedBox(height: 7),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.textMuted, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ReviewInfoRows extends StatelessWidget {
  final List<_ReviewInfoRow> rows;
  const _ReviewInfoRows({required this.rows});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Column(children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 112, child: Text(text.content(text.t(row.label)), style: const TextStyle(fontSize: AppTextSize.s13, color: AppColours.textMuted, fontWeight: FontWeight.w700))),
            Expanded(child: Text(text.content(text.t(row.value)), style: TextStyle(fontSize: AppTextSize.s13, color: row.valueColour ?? AppColours.textMain, fontWeight: FontWeight.w800))),
          ]),
        ),
    ]);
  }
}

class _ReviewInfoRow {
  final String label;
  final String value;
  final Color? valueColour;
  const _ReviewInfoRow({required this.label, required this.value, this.valueColour});
}
