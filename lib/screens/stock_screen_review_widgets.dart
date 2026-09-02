part of 'stock_screen.dart';

class _SelectionCircle extends StatelessWidget {
  final bool selected;
  final bool enabled;

  const _SelectionCircle({required this.selected, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final colour = enabled
        ? selected ? AppColours.blue : AppColours.border
        : const Color(0xFFD6DCE6);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected && enabled ? AppColours.blue : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: colour, width: 2),
      ),
      child: selected && enabled
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }
}

class _BulkSummaryCell extends StatelessWidget {
  final String text;
  final bool header;

  const _BulkSummaryCell(this.text, {this.header = false});

  @override
  Widget build(BuildContext context) {
    final appText = AppTextScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        appText.content(appText.t(text)),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppTextSize.s10,
          color: header ? AppColours.textMain : AppColours.textMuted,
          fontWeight: header ? FontWeight.w800 : FontWeight.w700,
          height: 1.05,
        ),
      ),
    );
  }
}

class _ReceivingReviewRow extends StatelessWidget {
  final StockReceivingRecord record;
  final String timerText;
  final String statusText;
  final Color statusColour;
  final Color conditionColour;
  final bool selectMode;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelectToggle;

  const _ReceivingReviewRow({
    required this.record,
    required this.timerText,
    required this.statusText,
    required this.statusColour,
    required this.conditionColour,
    required this.selectMode,
    required this.selectable,
    required this.selected,
    required this.onTap,
    required this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final item = record.items.isNotEmpty ? record.items.first : null;
    final text = AppTextScope.of(context);
    final condition = item?.condition ?? 'Unknown';
    final qty = item == null ? '-' : '${formatStockNumber(item.receivedQuantity)} ${item.unit}';
    final disabledInSelectMode = selectMode && !selectable;
    return Opacity(
      opacity: disabledInSelectMode ? 0.42 : 1,
      child: Pressable(
        onTap: selectMode ? (selectable ? onSelectToggle : null) : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              if (selectMode) ...[
                _SelectionCircle(selected: selected, enabled: selectable),
                const SizedBox(width: 8),
              ],
              _ReceivingGoodsThumb(record: record, size: 46, conditionColour: conditionColour),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(text.content(item?.skuName ?? record.supplierName), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 6),
                      Text(statusText, style: TextStyle(fontSize: AppTextSize.s12, color: statusColour, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 2),
                    Text('$qty · ${record.receivedBy} · $timerText', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(condition, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppTextSize.s12, color: conditionColour, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(disabledInSelectMode ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, color: AppColours.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyCountReviewRow extends StatelessWidget {
  final StockSubmission submission;
  final StockSku sku;
  final String timerText;
  final String statusText;
  final Color statusColour;
  final bool selectMode;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelectToggle;

  const _DailyCountReviewRow({
    required this.submission,
    required this.sku,
    required this.timerText,
    required this.statusText,
    required this.statusColour,
    required this.selectMode,
    required this.selectable,
    required this.selected,
    required this.onTap,
    required this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final disabledInSelectMode = selectMode && !selectable;
    return Opacity(
      opacity: disabledInSelectMode ? 0.42 : 1,
      child: Pressable(
        onTap: selectMode ? (selectable ? onSelectToggle : null) : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              if (selectMode) ...[
                _SelectionCircle(selected: selected, enabled: selectable),
                const SizedBox(width: 8),
              ],
              _SkuPhotoThumb(sku: sku, size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(text.content(sku.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 6),
                      Text(statusText, style: TextStyle(fontSize: AppTextSize.s12, color: statusColour, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 2),
                    Text('${formatStockNumber(submission.currentBalanceValue)} ${sku.unit} · ${submission.submittedBy} · $timerText', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s12, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(disabledInSelectMode ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, color: AppColours.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
