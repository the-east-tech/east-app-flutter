import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class PurchaseScreen extends StatefulWidget {
  final UserRole role;
  final List<SupplierProfile> suppliers;
  final void Function(SupplierProfile supplier) onCreateSupplier;

  const PurchaseScreen({
    super.key,
    required this.role,
    required this.suppliers,
    required this.onCreateSupplier,
  });

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final supplierNameController = TextEditingController();
  final contactController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final notesController = TextEditingController();

  bool get isHead => widget.role == UserRole.head;

  @override
  void dispose() {
    supplierNameController.dispose();
    contactController.dispose();
    phoneController.dispose();
    addressController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _createSupplier() async {
    final supplier = SupplierProfile(
      id: 'SUP${DateTime.now().millisecondsSinceEpoch}',
      supplierName: supplierNameController.text.trim().isEmpty
          ? 'New Supplier'
          : supplierNameController.text.trim(),
      supplierItem: 'General',
      contactPerson: contactController.text.trim(),
      phone: phoneController.text.trim(),
      address: addressController.text.trim(),
      notes: notesController.text.trim(),
      unit: 'unit',
      recommendedPurchaseAmount: 0,
      recommendedPurchaseFrequency: '',
      pricingPerUnit: 0,
      minimumBalanceValue: 0,
      maximumBalanceValue: 1,
      currentBalanceValue: 0,
      lastBalanceUpdatedAt: 'Not updated yet',
      lastBalanceUpdatedBy: 'Pending manager update',
    );

    final confirmed = await confirmDataChange(
      context,
      action: 'Create Supplier?',
      details: 'This will create a new supplier for the this business.',
    );
    if (!confirmed || !mounted) return;

    widget.onCreateSupplier(supplier);
    supplierNameController.clear();
    contactController.clear();
    phoneController.clear();
    addressController.clear();
    notesController.clear();
    showSuccessSnackBar(context, AppTextScope.of(context).t('Supplier created'));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
      children: [
        PageTitle(
          title: text.t('Purchase'),
          subtitle: isHead
              ? text.t('Create suppliers')
              : text.t('Supplier purchase setup is managed by Head'),
        ),
        if (isHead) ...[
          _CreateSupplierCard(
            supplierNameController: supplierNameController,
            contactController: contactController,
            phoneController: phoneController,
            addressController: addressController,
            notesController: notesController,
            onCreateSupplier: _createSupplier,
          ),
          const SizedBox(height: 22),
        ],
        WhiteCard(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColours.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.t('Supplier Purchase Setup'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text.t('Suppliers link inside SKU Setup.'),
                      style: const TextStyle(
                        fontSize: AppTextSize.s18,
                        color: AppColours.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SmallStatusPill(
                text: '${widget.suppliers.length} ${text.t('Suppliers')}',
                textColour: AppColours.green,
                backgroundColour: AppColours.greenSoft,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ...widget.suppliers.map((supplier) {
          return _SupplierCard(supplier: supplier);
        }),
      ],
    );
  }
}

class _CreateSupplierCard extends StatelessWidget {
  final TextEditingController supplierNameController;
  final TextEditingController contactController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController notesController;
  final VoidCallback onCreateSupplier;

  const _CreateSupplierCard({
    required this.supplierNameController,
    required this.contactController,
    required this.phoneController,
    required this.addressController,
    required this.notesController,
    required this.onCreateSupplier,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);

    return WhiteCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.add_business_outlined,
                color: AppColours.blue,
                size: 30,
              ),
              const SizedBox(width: 12),
              Text(
                text.t('Create Supplier'),
                style: const TextStyle(
                  fontSize: AppTextSize.s24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _PurchaseInput(
            label: text.t('Supplier Name'),
            controller: supplierNameController,
            hint: text.t('Example: Fresh Farm Supplier'),
          ),
          const SizedBox(height: 16),
          _PurchaseInput(
            label: text.t('Contact'),
            controller: contactController,
            hint: text.t('Example: Mr Tan'),
          ),
          const SizedBox(height: 16),
          _PurchaseInput(
            label: text.t('Phone'),
            controller: phoneController,
            hint: text.t('Example: 0123456789'),
          ),
          const SizedBox(height: 16),
          _PurchaseInput(
            label: text.t('Address'),
            controller: addressController,
            hint: text.t('Address'),
          ),
          const SizedBox(height: 16),
          _PurchaseInput(
            label: text.t('Notes'),
            controller: notesController,
            hint: text.t('Notes'),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            text: text.t('Create Supplier'),
            icon: Icons.add_rounded,
            onPressed: onCreateSupplier,
          ),
        ],
      ),
    );
  }
}


class _SupplierCard extends StatelessWidget {
  final SupplierProfile supplier;

  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final details = <Widget>[
      if (supplier.contactPerson.isNotEmpty)
        _SupplierInfoRow(label: text.t('Contact'), value: supplier.contactPerson),
      if (supplier.phone.isNotEmpty)
        _SupplierInfoRow(label: text.t('Phone'), value: supplier.phone),
      if (supplier.address.isNotEmpty)
        _SupplierInfoRow(label: text.t('Address'), value: supplier.address),
      if (supplier.notes.isNotEmpty)
        _SupplierInfoRow(label: text.t('Notes'), value: supplier.notes),
    ];

    return WhiteCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: AppColours.blue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  supplier.supplierName,
                  style: const TextStyle(
                    fontSize: AppTextSize.s24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...details,
          ],
        ],
      ),
    );
  }
}


class _SupplierInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _SupplierInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppTextSize.s17,
                color: AppColours.textMuted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppTextSize.s17,
                fontWeight: FontWeight.w700,
                color: AppColours.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _PurchaseInput({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.formLabel,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: AppTextStyles.formValue,
          decoration: AppInputStyle.decoration(
            hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

String formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
