import 'package:flutter/material.dart';

import '../localization/app_text_scope.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

enum AppScheduleType { adHoc, daily, weekly, monthly }

class ScheduleSelector extends StatelessWidget {
  final String title;
  final AppScheduleType value;
  final int? day;
  final DateTime? date;
  final ValueChanged<AppScheduleType> onTypeChanged;
  final ValueChanged<int?> onDayChanged;
  final ValueChanged<DateTime?> onDateChanged;

  const ScheduleSelector({
    super.key,
    required this.title,
    required this.value,
    required this.day,
    required this.date,
    required this.onTypeChanged,
    required this.onDayChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final description = switch (value) {
      AppScheduleType.adHoc => date == null
          ? text.t('Select one date.')
          : '${text.t('One-time on')} ${_formatDate(date!)}.',
      AppScheduleType.daily => text.t('Repeats every day.'),
      AppScheduleType.weekly =>
        '${text.t('Repeats every')} ${text.t(weekdays[((day ?? 1).clamp(1, 7)) - 1])}.',
      AppScheduleType.monthly => day == null
          ? text.t('Repeats on the last day of every month.')
          : '${text.t('Repeats monthly on Day')} $day.',
    };

    return WhiteCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.t(title),
            style: const TextStyle(
              fontSize: AppTextSize.s18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppScheduleType.values.map((type) {
              return ChoiceChip(
                label: Text(text.t(_label(type))),
                selected: value == type,
                onSelected: (_) => onTypeChanged(type),
              );
            }).toList(growable: false),
          ),
          if (value == AppScheduleType.adHoc) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickDate(context),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                date == null
                    ? text.t('Select date')
                    : _formatDate(date!),
              ),
            ),
          ],
          if (value == AppScheduleType.weekly) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: List.generate(7, (index) {
                final weekday = index + 1;
                return ChoiceChip(
                  label: Text(text.t(weekdays[index])),
                  selected: (day ?? 1) == weekday,
                  onSelected: (_) => onDayChanged(weekday),
                );
              }),
            ),
          ],
          if (value == AppScheduleType.monthly) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickMonthDay(context),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                day == null
                    ? text.t('Last day')
                    : '${text.t('Day')} $day',
              ),
            ),
          ],
          const SizedBox(height: 9),
          Text(
            description,
            style: const TextStyle(
              color: AppColours.textMuted,
              fontSize: AppTextSize.s13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: date ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: AppTextScope.of(context).t('Select date'),
    );
    if (selected != null) {
      onDateChanged(DateTime(selected.year, selected.month, selected.day));
    }
  }

  Future<void> _pickMonthDay(BuildContext context) async {
    final text = AppTextScope.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text.t('Monthly day'),
                style: const TextStyle(
                  fontSize: AppTextSize.s20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: List.generate(28, (index) {
                  final value = index + 1;
                  return ChoiceChip(
                    label: Text('$value'),
                    selected: day == value,
                    onSelected: (_) => Navigator.of(sheetContext).pop(value),
                  );
                }),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(0),
                icon: const Icon(Icons.last_page_rounded),
                label: Text(text.t('Last day of month')),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    onDayChanged(selected == 0 ? null : selected);
  }

  static String _label(AppScheduleType type) => switch (type) {
        AppScheduleType.adHoc => 'Ad hoc',
        AppScheduleType.daily => 'Daily',
        AppScheduleType.weekly => 'Weekly',
        AppScheduleType.monthly => 'Monthly',
      };

  static String _formatDate(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}
