part of 'stock_screen.dart';

class _AuditEntryCard extends StatefulWidget {
  final StockAuditEntry entry;

  const _AuditEntryCard({required this.entry});

  @override
  State<_AuditEntryCard> createState() => _AuditEntryCardState();
}

class _AuditEntryCardState extends State<_AuditEntryCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final text = AppTextScope.of(context);
    final roleText = entry.actorRole.isEmpty ? '-' : entry.actorRole.toUpperCase();
    final hasDetails = entry.changes.isNotEmpty || entry.note.trim().isNotEmpty;
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: hasDetails ? () => setState(() => expanded = !expanded) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(text.t(entry.action), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s16, fontWeight: FontWeight.w800, color: AppColours.textMain))),
                    SmallStatusPill(text: text.t(entry.module), textColour: AppColours.blue, backgroundColour: AppColours.blueSoft),
                  ]),
                  const SizedBox(height: 3),
                  Text(text.content(entry.itemName), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s14, fontWeight: FontWeight.w700, color: AppColours.textMain)),
                  const SizedBox(height: 3),
                  Text('${entry.actorName} · ${entry.actorId} · $roleText · ${entry.timestampText}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w600, color: AppColours.textMuted, height: 1.25)),
                  if (hasDetails) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(text.t(entry.changes.isEmpty ? 'Details' : '${entry.changes.length} change${entry.changes.length == 1 ? '' : 's'}'), style: const TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w800, color: AppColours.blue)),
                      const SizedBox(width: 2),
                      Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: AppColours.blue),
                    ]),
                  ],
                ])),
              ]),
              if (expanded && entry.changes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(color: AppColours.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColours.border)),
                  child: Column(children: [
                    for (var i = 0; i < entry.changes.length; i++) ...[
                      _AuditChangeRow(change: entry.changes[i]),
                      if (i != entry.changes.length - 1) const Divider(height: 1),
                    ],
                  ]),
                ),
              ],
              if (expanded && entry.note.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(text.content(entry.note), style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w600, color: AppColours.textMuted)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _AuditChangeRow extends StatelessWidget {
  final StockAuditChange change;
  const _AuditChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 96, child: Text(text.t(change.field), style: const TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w800, color: AppColours.textMuted))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text.content(text.t(change.oldValue)), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w600, color: AppColours.textMuted)),
          const SizedBox(height: 3),
          Row(children: [const Icon(Icons.arrow_downward_rounded, size: 13, color: AppColours.blue), const SizedBox(width: 4), Text(text.t('changed to'), style: const TextStyle(fontSize: AppTextSize.s12, fontWeight: FontWeight.w700, color: AppColours.blue))]),
          const SizedBox(height: 3),
          Text(text.content(text.t(change.newValue)), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextSize.s13, fontWeight: FontWeight.w800, color: AppColours.textMain)),
        ])),
      ]),
    );
  }
}
