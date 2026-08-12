import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../services/east_app_api.dart';
import 'app_feedback.dart';


Future<void> showApiErrorDialog(
  BuildContext context,
  EastAppApiException error,
) async {
  await AppFeedback.error();
  if (!context.mounted) return;

  final details = error.technicalDetails;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final screenHeight = MediaQuery.of(dialogContext).size.height;
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColours.red),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Technical Error',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: screenHeight * 0.68,
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              details,
              style: const TextStyle(
                fontSize: AppTextSize.s13,
                height: 1.45,
                color: AppColours.textMain,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: details));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Error details copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}


Future<bool> confirmDataChange(
  BuildContext context, {
  required String action,
  String? details,
}) async {
  await AppFeedback.warning();
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColours.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Text(
        details ??
            'Please review the information carefully. This will change business data.',
        style: const TextStyle(
          fontSize: AppTextSize.s14,
          height: 1.4,
          color: AppColours.textMain,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Proceed'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

void showSuccessSnackBar(BuildContext context, String message) {
  if (!_shouldShowSuccessBurst(message)) {
    return;
  }

  AppFeedback.success();
  _showSuccessBurstOverlay(context, _successBurstMessage(message));
}

void showWarningSnackBar(BuildContext context, String message) {
  // Validation is shown inline inside the active form.
  // Keep only warning feedback so popups do not block action buttons.
  AppFeedback.warning();
}

void showErrorSnackBar(BuildContext context, String message) {
  AppFeedback.error();
  _showAppSnackBar(
    context,
    _compactSnackBarMessage(message),
    icon: Icons.error_rounded,
    backgroundColor: AppColours.red,
    duration: const Duration(milliseconds: 1900),
  );
}

void showTemporaryDisabledMessage(BuildContext context) {
  AppFeedback.warning();
  _showAppSnackBar(
    context,
    'Temporary disabled',
    icon: Icons.schedule_rounded,
    backgroundColor: AppColours.textMain,
    duration: const Duration(milliseconds: 1500),
  );
}

String _compactSnackBarMessage(String message) {
  final trimmed = message.trim();
  final value = trimmed.toLowerCase();

  if (value.contains('complete supplier') && value.contains('quantit')) {
    return 'Complete supplier, SKU & qty';
  }
  if (value.contains('invoice photo') && value.contains('goods')) {
    return 'Add invoice & goods photos';
  }
  if (value.contains('valid stock numbers')) {
    return 'Enter valid stock numbers';
  }
  if (value.contains('valid stock number')) {
    return 'Enter valid stock number';
  }
  if (value.contains('complete every sku')) {
    return 'Complete every SKU';
  }
  if (value.startsWith('please ')) {
    return trimmed.substring(7);
  }
  return trimmed;
}


bool _shouldShowSuccessBurst(String message) {
  final value = message.trim().toLowerCase();
  if (value.isEmpty) return false;

  final blockedWords = [
    'please',
    'select',
    'required',
    'invalid',
    'valid stock',
    'complete every',
    'reject',
    'rejected',
    'error',
    'warning',
    'copied',
    'captured',
    'camera',
    'photo',
    'clipboard',
    'inactive',
  ];

  if (blockedWords.any(value.contains)) return false;

  final successWords = [
    'approve',
    'approved',
    'save',
    'saved',
    'submit',
    'submitted',
    'create',
    'created',
    'update',
    'updated',
    'complete',
    'completed',
  ];

  return successWords.any(value.contains);
}

String _successBurstMessage(String message) {
  final trimmed = message.trim();
  final value = trimmed.toLowerCase();

  if (value == 'saved') return 'Saved';
  if (value.contains('approved')) return 'Approved';
  if (value.contains('submitted')) return 'Submitted';
  if (value.contains('updated')) return 'Updated';
  if (value.contains('created')) return 'Created';
  if (value.contains('completed')) return 'Completed';
  if (value.contains('save')) return 'Saved';
  if (value.contains('submit')) return 'Submitted';
  if (value.contains('approve')) return 'Approved';
  if (value.contains('update')) return 'Updated';
  if (value.contains('create')) return 'Created';

  return trimmed;
}

void _showSuccessBurstOverlay(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _SuccessBurstOverlay(message: message),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1700), () {
    try {
      entry.remove();
    } catch (_) {
      // Overlay may already be gone when route changes.
    }
  });
}

class _SuccessBurstOverlay extends StatefulWidget {
  final String message;

  const _SuccessBurstOverlay({required this.message});

  @override
  State<_SuccessBurstOverlay> createState() => _SuccessBurstOverlayState();
}

class _SuccessBurstOverlayState extends State<_SuccessBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  double _slice(double start, double end) {
    final raw = ((controller.value - start) / (end - start)).clamp(0.0, 1.0);
    return raw.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final appear = Curves.easeOutBack.transform(_slice(0.00, 0.38));
            final float = Curves.easeOutCubic.transform(_slice(0.10, 1.00));
            final fadeOut = Curves.easeIn.transform(_slice(0.72, 1.00));
            final particleMove = Curves.easeOutCubic.transform(_slice(0.06, 0.86));
            final particleFade = (1 - _slice(0.58, 1.00)).clamp(0.0, 1.0).toDouble();
            final pulse = 1 + (0.06 * Curves.easeOut.transform(_slice(0.18, 0.42)));

            return Opacity(
              opacity: 1 - fadeOut,
              child: Align(
                alignment: const Alignment(0, -0.32),
                child: Transform.translate(
                  offset: Offset(0, -18 * float),
                  child: SizedBox(
                    width: 300,
                    height: 200,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        ..._successBurstParticles.map(
                          (particle) => _BurstParticle(
                            data: particle,
                            move: particleMove,
                            opacity: particleFade,
                          ),
                        ),
                        Transform.scale(
                          scale: (0.72 + (0.28 * appear)) * pulse,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 270),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColours.green, AppColours.blue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColours.green.withValues(alpha: 0.28),
                                  blurRadius: 26,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Flexible(
                                  child: Text(
                                    widget.message,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: AppTextSize.s15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
class _BurstParticle extends StatelessWidget {
  final _BurstParticleData data;
  final double move;
  final double opacity;

  const _BurstParticle({
    required this.data,
    required this.move,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(data.dx * move, data.dy * move),
      child: Transform.rotate(
        angle: data.turn * move,
        child: Opacity(
          opacity: opacity,
          child: Icon(
            data.icon,
            color: data.color,
            size: data.size,
          ),
        ),
      ),
    );
  }
}

class _BurstParticleData {
  final IconData icon;
  final double dx;
  final double dy;
  final double size;
  final double turn;
  final Color color;

  const _BurstParticleData({
    required this.icon,
    required this.dx,
    required this.dy,
    required this.size,
    required this.turn,
    required this.color,
  });
}

const _successBurstParticles = [
  _BurstParticleData(icon: Icons.auto_awesome_rounded, dx: -92, dy: -58, size: 22, turn: -0.50, color: AppColours.gold),
  _BurstParticleData(icon: Icons.circle_rounded, dx: -78, dy: 36, size: 13, turn: 0.20, color: AppColours.orange),
  _BurstParticleData(icon: Icons.star_rounded, dx: -40, dy: -88, size: 19, turn: 0.80, color: AppColours.gold),
  _BurstParticleData(icon: Icons.auto_awesome_rounded, dx: 42, dy: -86, size: 20, turn: 0.55, color: AppColours.green),
  _BurstParticleData(icon: Icons.circle_rounded, dx: 88, dy: -36, size: 14, turn: -0.30, color: AppColours.gold),
  _BurstParticleData(icon: Icons.star_rounded, dx: 76, dy: 44, size: 18, turn: -0.75, color: AppColours.blueSoft),
  _BurstParticleData(icon: Icons.circle_rounded, dx: -28, dy: 76, size: 11, turn: 0.30, color: AppColours.green),
  _BurstParticleData(icon: Icons.auto_awesome_rounded, dx: 18, dy: 82, size: 17, turn: 0.60, color: AppColours.orange),
];

void _showAppSnackBar(
  BuildContext context,
  String message, {
  required IconData icon,
  required Color backgroundColor,
  Duration duration = const Duration(milliseconds: 1800),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  var removed = false;

  void removeEntry() {
    if (removed) return;
    removed = true;
    try {
      entry.remove();
    } catch (_) {
      // Overlay may already be gone when route changes.
    }
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      final top = (media.size.height * 0.30).clamp(media.padding.top + 72, media.size.height * 0.42).toDouble();
      return Positioned(
        left: 18,
        right: 18,
        top: top,
        child: SafeArea(
          bottom: false,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: AppTextSize.s13,
                        height: 1.20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: removeEntry,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  Future.delayed(duration, removeEntry);
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool pressed = false;

  void updatePressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => updatePressed(true),
      onPointerUp: (_) => updatePressed(false),
      onPointerCancel: (_) => updatePressed(false),
      child: AnimatedScale(
        scale: pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  AppFeedback.tap();
                  widget.onTap!();
                },
          borderRadius: widget.borderRadius ?? BorderRadius.circular(18),
          child: widget.child,
        ),
      ),
    );
  }
}

class WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const WhiteCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColours.border),
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool outlined;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTextSize.s18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return Pressable(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: outlined ? Colors.white : AppColours.blue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: outlined ? AppColours.border : AppColours.blue,
            ),
          ),
          child: IconTheme(
            data: IconThemeData(
              color: outlined ? AppColours.textMain : Colors.white,
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: outlined ? AppColours.textMain : Colors.white,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class SegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final void Function(int index) onChanged;

  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E9ED),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;

          return Expanded(
            child: Pressable(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: tabs.length > 3 ? AppTextSize.s15 : AppTextSize.s17,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColours.textMain
                        : AppColours.textMain.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const PageTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppTextSize.s34,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: AppColours.textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: AppTextSize.s18,
              fontWeight: FontWeight.w500,
              color: AppColours.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class SmallStatusPill extends StatelessWidget {
  final String text;
  final Color textColour;
  final Color backgroundColour;
  final IconData? icon;

  const SmallStatusPill({
    super.key,
    required this.text,
    required this.textColour,
    required this.backgroundColour,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColour,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: textColour),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColour,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AppProcessingOverlay extends StatelessWidget {
  final bool isProcessing;
  final Widget child;

  const AppProcessingOverlay({
    super.key,
    required this.isProcessing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isProcessing,
      child: Stack(
        fit: StackFit.expand,
        children: [
        AbsorbPointer(
          absorbing: isProcessing,
          child: child,
        ),
        if (isProcessing) ...[
          const ModalBarrier(
            dismissible: false,
            color: Color(0x99000000),
          ),
          Center(
            child: Semantics(
              liveRegion: true,
              label: 'Processing. Please wait.',
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing... Please Wait!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTextSize.s16,
                        fontWeight: FontWeight.w800,
                        color: AppColours.textMain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
      ),
    );
  }
}

