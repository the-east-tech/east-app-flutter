import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../localization/app_text_scope.dart';
import '../theme/app_theme.dart';

class DeviceContactPhone {
  final String name;
  final String number;

  const DeviceContactPhone({required this.name, required this.number});
}

class DeviceContactsPermissionException implements Exception {
  const DeviceContactsPermissionException();
}

List<DeviceContactPhone>? _cachedContactPhones;

Future<List<DeviceContactPhone>> loadDeviceContactPhones() async {
  var status = await FlutterContacts.permissions.check(PermissionType.read);
  if (status != PermissionStatus.granted) {
    status = await FlutterContacts.permissions.request(PermissionType.read);
  }
  if (status != PermissionStatus.granted) {
    throw const DeviceContactsPermissionException();
  }

  final cached = _cachedContactPhones;
  if (cached != null) return cached;

  final contacts = await FlutterContacts.getAll(
    properties: const {ContactProperty.phone},
  );
  final phones = <DeviceContactPhone>[];
  for (final contact in contacts) {
    final name = contact.displayName?.trim() ?? '';
    for (final phone in contact.phones) {
      final normalized = phone.normalizedNumber?.trim();
      final number = normalized == null || normalized.isEmpty
          ? phone.number.trim()
          : normalized;
      if (number.isEmpty) continue;
      phones.add(
        DeviceContactPhone(
          name: name.isEmpty ? number : name,
          number: number,
        ),
      );
    }
  }
  phones.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return _cachedContactPhones = List.unmodifiable(phones);
}

Future<DeviceContactPhone?> showDeviceContactPhonePicker(
  BuildContext context,
  List<DeviceContactPhone> phones,
) {
  return showModalBottomSheet<DeviceContactPhone>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _DeviceContactPicker(phones: phones),
  );
}

class _DeviceContactPicker extends StatefulWidget {
  final List<DeviceContactPhone> phones;

  const _DeviceContactPicker({required this.phones});

  @override
  State<_DeviceContactPicker> createState() => _DeviceContactPickerState();
}

class _DeviceContactPickerState extends State<_DeviceContactPicker> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final search = query.trim().toLowerCase();
    final filtered = search.isEmpty
        ? widget.phones
        : widget.phones.where((phone) {
            return '${phone.name} ${phone.number}'
                .toLowerCase()
                .contains(search);
          }).toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppColours.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text.t('Contacts'),
                style: const TextStyle(
                  fontSize: AppTextSize.s24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: AppInputStyle.decoration(
                text.t('Search contacts'),
              ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(text.t('No contacts with phone numbers')))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final phone = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: const CircleAvatar(
                            backgroundColor: AppColours.blueSoft,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: AppColours.blue,
                            ),
                          ),
                          title: Text(
                            phone.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(phone.number),
                          onTap: () => Navigator.of(context).pop(phone),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
