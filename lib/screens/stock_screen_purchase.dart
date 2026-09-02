part of 'stock_screen.dart';

class _RestockMessagePage extends StatefulWidget {
  final List<SupplierProfile> suppliers;
  final List<StockSku> skus;
  final VoidCallback onBack;

  const _RestockMessagePage({
    required this.suppliers,
    required this.skus,
    required this.onBack,
  });

  @override
  State<_RestockMessagePage> createState() => _RestockMessagePageState();
}

class _RestockMessagePageState extends State<_RestockMessagePage> {
  bool lowStockOnly = true;

  SupplierProfile? supplierFor(String supplierId) {
    for (final supplier in widget.suppliers) {
      if (supplier.id == supplierId) return supplier;
    }
    return null;
  }

  List<StockSku> get lowSkus =>
      widget.skus.where((sku) => sku.isBelowMinimumBalance).toList();

  SupplierProfile? preferredSupplierFor(StockSku sku) {
    if (sku.supplierIds.isEmpty) return null;
    return supplierFor(sku.supplierIds.first);
  }

  List<StockSku> get visibleSkus => lowStockOnly ? lowSkus : widget.skus;

  List<_RestockSupplierGroup> supplierGroups({List<StockSku>? source}) {
    final grouped = <String, _RestockSupplierGroup>{};
    for (final sku in source ?? visibleSkus) {
      if (sku.supplierIds.isEmpty) {
        grouped.putIfAbsent(
          'UNASSIGNED',
          () => const _RestockSupplierGroup(supplier: null, skus: <StockSku>[]),
        );
        grouped['UNASSIGNED']!.skus.add(sku);
        continue;
      }

      for (final supplierId in sku.supplierIds) {
        final supplier = supplierFor(supplierId);
        final key = supplier?.id ?? 'UNASSIGNED';
        grouped.putIfAbsent(
          key,
          () => _RestockSupplierGroup(supplier: supplier, skus: <StockSku>[]),
        );
        grouped[key]!.skus.add(sku);
      }
    }
    final groups = grouped.values.toList();
    groups.sort((a, b) => a.supplierName.compareTo(b.supplierName));
    return groups;
  }

  String purchaseDateTime() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final suffix = now.hour >= 12 ? 'pm' : 'am';
    return '${two(now.day)}/${two(now.month)}/${now.year} ${two(hour12)}:${two(now.minute)}$suffix';
  }

  String buildSupplierMessage(
    _RestockSupplierGroup group, [
    String Function(String value)? translate,
  ]) {
    final lines = <String>[];
    for (var i = 0; i < group.skus.length; i++) {
      final sku = group.skus[i];
      lines.add(
        '${i + 1}. ${translate?.call(sku.name) ?? sku.name} - ${formatStockNumber(sku.suggestedRestockAmount)} ${sku.unit}',
      );
    }
    lines.add('');
    lines.add(purchaseDateTime());
    lines.add('Please confirm availability and delivery time. Thank u.');
    return lines.join('\n');
  }

  String buildAllSupplierMessages([String Function(String value)? translate]) {
    final groups = supplierGroups();
    if (groups.isEmpty) return 'No restock needed today.';
    return groups
        .map((group) => buildSupplierMessage(group, translate))
        .join('\n\n---\n\n');
  }

  void copySupplierMessage(BuildContext context, _RestockSupplierGroup group) {
    final text = AppTextScope.of(context);
    Clipboard.setData(
      ClipboardData(text: buildSupplierMessage(group, text.content)),
    );
    showSuccessSnackBar(context, text.t('Supplier restock message copied'));
  }

  void copyAllSupplierMessages(BuildContext context) {
    final text = AppTextScope.of(context);
    Clipboard.setData(
      ClipboardData(text: buildAllSupplierMessages(text.content)),
    );
    showSuccessSnackBar(context, text.t('All supplier messages copied'));
  }

  _RestockSupplierGroup supplierGroupForSku(StockSku sku) {
    final supplier = preferredSupplierFor(sku);
    final skus = visibleSkus.where((candidate) {
      final candidateSupplier = preferredSupplierFor(candidate);
      return candidateSupplier?.id == supplier?.id;
    }).toList();

    return _RestockSupplierGroup(supplier: supplier, skus: skus);
  }

  Widget restockSupplierGridCard(BuildContext context, _RestockSupplierGroup group) {
    final text = AppTextScope.of(context);
    final message = buildSupplierMessage(group, text.content);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: () => showRestockMessageDialog(context, message),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColours.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColours.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.skus.length} ${text.t('items')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s12,
                        color: AppColours.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget lowStockGridCard(BuildContext context, StockSku sku) {
    final text = AppTextScope.of(context);
    final group = supplierGroupForSku(sku);
    final supplier = preferredSupplierFor(sku);
    final message = buildSupplierMessage(group, text.content);

    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Pressable(
        onTap: () => showRestockMessageDialog(context, message),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColours.redSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.priority_high_rounded,
                      color: AppColours.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text.content(sku.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatStockNumber(sku.suggestedRestockAmount)} ${sku.unit}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s15,
                  color: AppColours.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                supplier?.supplierName ?? text.t('Unassigned Supplier'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${text.t('Current')}: ${formatStockNumber(sku.currentBalanceValue)} ${sku.unit}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTextSize.s13,
                  color: AppColours.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget compactCardGrid({
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 330;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: cardWidth, height: 62, child: child))
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final skus = visibleSkus;

    final groups = supplierGroups(source: skus);

    return _PageScaffold(
      title: text.t('Purchase'),
      subtitle: text.t('Tap supplier to preview message.'),
      onBack: widget.onBack,
      children: [
        WhiteCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: lowStockOnly,
              onChanged: (value) => setState(() => lowStockOnly = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                text.t('Low Stock Only'),
                style: const TextStyle(fontSize: AppTextSize.s18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          WhiteCard(
            padding: const EdgeInsets.all(22),
            child: Text(
              lowStockOnly ? text.t('No low-stock SKU today.') : text.t('No SKU found.'),
              style: const TextStyle(fontSize: AppTextSize.s20, fontWeight: FontWeight.w700),
            ),
          )
        else
          compactCardGrid(
            children: groups.map((group) => restockSupplierGridCard(context, group)).toList(),
          ),
      ],
    );
  }
}

class _RestockSupplierGroup {
  final SupplierProfile? supplier;
  final List<StockSku> skus;

  const _RestockSupplierGroup({
    required this.supplier,
    required this.skus,
  });

  String get supplierName => supplier?.supplierName ?? 'Unassigned Supplier';
}

void showRestockMessageDialog(BuildContext context, String message) {
  final text = AppTextScope.of(context);

  showStockBottomSheet<void>(
    context,
    maxHeightFactor: 0.86,
    builder: (sheetContext) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stockBottomSheetHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    text.t('Message'),
                    style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColours.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColours.border),
              ),
              child: SelectableText(
                message,
                style: const TextStyle(
                  fontSize: AppTextSize.s18,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              text.t('Review the message, then copy and paste it to supplier chat.'),
              style: const TextStyle(
                fontSize: AppTextSize.s16,
                color: AppColours.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              text: text.t('Copy Message'),
              icon: Icons.content_copy_rounded,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                showSuccessSnackBar(context, text.t('Message copied to clipboard'));
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showCameraOnlyCaptureDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Future<void> Function(String filePath) onCaptured,
}) async {
  final filePath = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _StockCameraPage(
        title: title,
        subtitle: subtitle,
      ),
    ),
  );
  if (filePath == null || filePath.trim().isEmpty || !context.mounted) return;
  await onCaptured(filePath);
}
