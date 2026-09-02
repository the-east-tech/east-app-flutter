part of 'stock_screen.dart';

class _SkuCsvPreviewRow extends StatelessWidget {
  final String label;
  final int value;
  final Color? colour;

  const _SkuCsvPreviewRow({required this.label, required this.value, this.colour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        Expanded(child: Text(label)),
        Text('$value', style: TextStyle(color: colour ?? AppColours.textMain, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _SkuCompactRow extends StatelessWidget {
  final StockSku sku;
  final VoidCallback onTap;

  const _SkuCompactRow({required this.sku, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final isLow = sku.isBelowMinimumBalance;
    final statusText = isLow ? text.t('Low') : text.t('Good');
    final statusColour = isLow ? AppColours.red : AppColours.green;
    final statusBackground = isLow ? AppColours.redSoft : AppColours.greenSoft;
    final balanceColour = isLow ? AppColours.red : AppColours.green;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
        child: Row(children: [
          GestureDetector(onTap: () => showSkuPhotoViewer(context, sku: sku), child: _SkuPhotoThumb(sku: sku, size: 56)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(text.content(sku.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${text.content(sku.category)} · ${sku.unit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s13, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${sku.assignedStaffName} · ${text.t('Reset')} ${sku.resetTime}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w700, color: AppColours.textMuted)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            SmallStatusPill(text: statusText, textColour: statusColour, backgroundColour: statusBackground),
            const SizedBox(height: 8),
            _SkuTripleValue(sku: sku, balanceColour: balanceColour, fontSize: AppTextSize.s15),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColours.textMuted),
        ]),
      ),
    );
  }
}

class _SkuTripleValue extends StatelessWidget {
  final StockSku sku;
  final Color balanceColour;
  final double fontSize;

  const _SkuTripleValue({required this.sku, required this.balanceColour, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final unit = sku.unit;
    final min = formatStockNumber(sku.minimumBalanceValue);
    final current = formatStockNumber(sku.currentBalanceValue);
    final max = formatStockNumber(sku.maximumBalanceValue);
    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        style: TextStyle(fontSize: fontSize, color: AppColours.textMain, fontWeight: FontWeight.w700),
        children: [
          TextSpan(text: '$min / '),
          TextSpan(text: current, style: TextStyle(color: balanceColour)),
          TextSpan(text: ' / $max $unit'),
        ],
      ),
    );
  }
}

void showSkuDetailDialog(
  BuildContext context, {
  required StockSku sku,
  required List<StockTag> tags,
  required List<SupplierProfile> suppliers,
  required Future<void> Function(StockSku sku) onUpdateSku,
  required Future<void> Function(String skuId, double balance, String updatedBy) onUpdateSkuBalance,
}) {
  showStockBottomSheet<void>(
    context,
    maxHeightFactor: 0.94,
    builder: (sheetContext) => _SkuDetailContent(
      sku: sku,
      tags: tags,
      suppliers: suppliers,
      onUpdateSku: onUpdateSku,
      onUpdateSkuBalance: onUpdateSkuBalance,
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}
