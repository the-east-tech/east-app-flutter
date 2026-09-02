part of 'stock_screen.dart';

class _SetupDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextEditingController? controller;
  final bool isEditing;
  final TextInputType? keyboardType;

  const _SetupDetailRow({required this.label, required this.value, this.controller, this.isEditing = false, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    final editable = isEditing && controller != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColours.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: AppTextStyles.formLabel)),
        const SizedBox(width: 14),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: editable ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : EdgeInsets.zero,
            decoration: editable
                ? BoxDecoration(color: AppColours.blueSoft.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColours.blue.withValues(alpha: 0.18)))
                : null,
            child: editable
                ? TextField(controller: controller, textAlign: TextAlign.right, keyboardType: keyboardType, style: AppTextStyles.formValue, decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6)))
                : Text(value.isEmpty ? '-' : AppTextScope.of(context).content(value), textAlign: TextAlign.right, style: AppTextStyles.formValue),
          ),
        ),
      ]),
    );
  }
}

class _SkuBalanceSummary extends StatelessWidget {
  final StockSku sku;
  final double? currentBalance;

  const _SkuBalanceSummary({required this.sku, this.currentBalance});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final current = currentBalance ?? sku.currentBalanceValue;
    final maximum = sku.maximumBalanceValue <= 0 ? 1.0 : sku.maximumBalanceValue;
    final ratio = (current / maximum).clamp(0.0, 1.0).toDouble();
    final belowMinimum = current < sku.minimumBalanceValue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: belowMinimum ? AppColours.redSoft : AppColours.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: belowMinimum ? AppColours.red : AppColours.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(text.t('Stock Level'), style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w700))),
          Text('${formatStockNumber(current)} / ${formatStockNumber(sku.maximumBalanceValue)} ${sku.unit}', style: TextStyle(fontSize: AppTextSize.s15, color: belowMinimum ? AppColours.red : AppColours.textMuted, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) => Stack(children: [
          Container(height: 18, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColours.border))),
          AnimatedContainer(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, height: 18, width: constraints.maxWidth * ratio, decoration: BoxDecoration(color: belowMinimum ? AppColours.red : AppColours.green, borderRadius: BorderRadius.circular(99))),
        ])),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text('${text.t('Current')}: ${formatStockNumber(current)} ${sku.unit}', style: TextStyle(fontSize: AppTextSize.s14, color: belowMinimum ? AppColours.red : AppColours.textMuted, fontWeight: FontWeight.w700))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${text.t('Minimum')}: ${formatStockNumber(sku.minimumBalanceValue)} ${sku.unit}', style: const TextStyle(fontSize: AppTextSize.s14, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
            Text('${text.t('Maximum')}: ${formatStockNumber(sku.maximumBalanceValue)} ${sku.unit}', style: const TextStyle(fontSize: AppTextSize.s14, color: AppColours.textMuted, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: AppTextStyles.formLabel));
}

class _InlineError extends StatelessWidget {
  final String text;
  const _InlineError(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 5), child: Text(text, style: const TextStyle(color: AppColours.red, fontSize: AppTextSize.s12, fontWeight: FontWeight.w700)));
}

InputDecoration _inputDecoration(String hint, {String? suffixText, String? prefixText}) => AppInputStyle.decoration(hint, suffixText: suffixText, prefixText: prefixText);

class _DialogInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? suffixText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _DialogInput({required this.label, required this.controller, required this.hint, this.suffixText, this.errorText, this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _FieldLabel(label),
    TextField(
      controller: controller,
      style: AppTextStyles.formValue,
      textInputAction: TextInputAction.done,
      keyboardType: suffixText == null ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: _inputDecoration(hint, suffixText: suffixText).copyWith(errorText: errorText),
    ),
  ]);
}

class _DialogBareInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffixText;
  final String? prefixText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _DialogBareInput({required this.controller, required this.hint, this.suffixText, this.prefixText, this.errorText, this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: AppTextStyles.formValue,
    textInputAction: TextInputAction.done,
    keyboardType: suffixText == null && prefixText == null ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
    onChanged: onChanged,
    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    decoration: _inputDecoration(hint, suffixText: suffixText, prefixText: prefixText).copyWith(errorText: errorText),
  );
}

void showAddSupplierDialog(BuildContext context, {required Future<void> Function(SupplierProfile supplier) onCreateSupplier}) {
  final text = AppTextScope.of(context);
  final name = TextEditingController();
  final contact = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final notes = TextEditingController();
  showStockBottomSheet<void>(
    context,
    maxHeightFactor: 0.9,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        stockBottomSheetHandle(),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: Text(text.t('Add Supplier'), style: const TextStyle(fontSize: AppTextSize.s26, fontWeight: FontWeight.w700))), IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close_rounded))]),
        const SizedBox(height: 16),
        _DialogInput(label: text.t('Supplier Name'), controller: name, hint: text.t('Example: GTI Kampar')),
        const SizedBox(height: 14),
        _DialogInput(label: text.t('Contact'), controller: contact, hint: text.t('Example: Mr Tan')),
        const SizedBox(height: 14),
        _DialogInput(label: text.t('Phone'), controller: phone, hint: text.t('Example: 0123456789')),
        const SizedBox(height: 14),
        _DialogInput(label: text.t('Address'), controller: address, hint: text.t('Address')),
        const SizedBox(height: 14),
        _DialogInput(label: text.t('Notes'), controller: notes, hint: text.t('Notes')),
        const SizedBox(height: 18),
        PrimaryButton(
          text: text.t('Save Supplier'),
          icon: Icons.save_outlined,
          onPressed: () async {
            final supplier = SupplierProfile(
              id: 'SUP${DateTime.now().millisecondsSinceEpoch}',
              supplierName: name.text.trim().isEmpty ? 'New Supplier' : name.text.trim(),
              supplierItem: 'General',
              contactPerson: contact.text.trim(),
              phone: phone.text.trim(),
              address: address.text.trim(),
              notes: notes.text.trim(),
              unit: 'unit',
              recommendedPurchaseAmount: 0,
              recommendedPurchaseFrequency: '',
              pricingPerUnit: 0,
              minimumBalanceValue: 0,
              maximumBalanceValue: 1,
              currentBalanceValue: 0,
              lastBalanceUpdatedAt: 'Not counted yet',
              lastBalanceUpdatedBy: headId,
            );
            final confirmed = await confirmDataChange(context, action: 'Create Supplier?', details: 'This will create a new supplier for the this business.');
            if (!confirmed || !context.mounted) return;
            final saved = await runStockRequest(context, () => onCreateSupplier(supplier));
            if (!saved || !context.mounted || !sheetContext.mounted) return;
            Navigator.of(sheetContext).pop();
            showSuccessSnackBar(context, text.t('Supplier created'));
          },
        ),
      ]),
    ),
  );
}

String formatStockNumber(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

String formatStockResetTime(TimeOfDay value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

TimeOfDay parseStockResetTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length == 2) {
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) return TimeOfDay(hour: hour, minute: minute);
  }
  return const TimeOfDay(hour: 8, minute: 0);
}

bool isValidStockResetTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) return false;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}
