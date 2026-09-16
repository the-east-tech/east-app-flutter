import 'package:flutter/material.dart';

import 'app_feedback.dart';

class InteractiveSwipeBack extends StatefulWidget {
  final bool enabled;
  final Widget previousPage;
  final VoidCallback onBack;
  final Widget child;

  const InteractiveSwipeBack({
    super.key,
    required this.enabled,
    required this.previousPage,
    required this.onBack,
    required this.child,
  });

  @override
  State<InteractiveSwipeBack> createState() => _InteractiveSwipeBackState();
}

class _InteractiveSwipeBackState extends State<InteractiveSwipeBack>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  double dragOffset = 0;
  double dragStartX = 0;
  double viewportWidth = 1;
  double animationStart = 0;
  double animationEnd = 0;
  bool dragging = false;
  bool completeAfterAnimation = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )
      ..addListener(handleAnimationTick)
      ..addStatusListener(handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant InteractiveSwipeBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      controller.stop();
      dragOffset = 0;
      dragging = false;
      completeAfterAnimation = false;
    }
  }

  void handleAnimationTick() {
    final value = Curves.easeOutCubic.transform(controller.value);
    setState(() {
      dragOffset = animationStart + (animationEnd - animationStart) * value;
    });
  }

  void handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final shouldComplete = completeAfterAnimation;
    completeAfterAnimation = false;
    dragging = false;
    if (shouldComplete) {
      widget.onBack();
      if (!mounted) return;
    }
    setState(() => dragOffset = 0);
  }

  void handleDragStart(DragStartDetails details) {
    controller.stop();
    dragStartX = details.globalPosition.dx;
    setState(() => dragging = true);
  }

  void handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final nextOffset =
        (dragOffset + delta).clamp(0.0, viewportWidth).toDouble();
    if (nextOffset == dragOffset) return;
    setState(() => dragOffset = nextOffset);
  }

  void handleDragEnd(DragEndDetails details) {
    final edgeSwipe = dragStartX <= 48;
    final distanceThreshold = edgeSwipe ? 32.0 : 72.0;
    final velocityThreshold = edgeSwipe ? 180.0 : 380.0;
    final velocity = details.primaryVelocity ?? 0;
    final complete =
        dragOffset >= distanceThreshold || velocity >= velocityThreshold;

    if (complete) AppFeedback.swipeBack();
    animateTo(complete ? viewportWidth : 0, complete: complete);
  }

  void animateTo(double target, {required bool complete}) {
    animationStart = dragOffset;
    animationEnd = target;
    completeAfterAnimation = complete;
    controller.duration = Duration(
      milliseconds: complete ? 160 : 130,
    );

    if (animationStart == animationEnd) {
      if (complete) widget.onBack();
      setState(() {
        dragOffset = 0;
        dragging = false;
        completeAfterAnimation = false;
      });
      return;
    }
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final progress =
            (dragOffset / viewportWidth).clamp(0.0, 1.0).toDouble();
        final revealPreviousPage = dragging || dragOffset > 0;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: handleDragStart,
          onHorizontalDragUpdate: handleDragUpdate,
          onHorizontalDragEnd: handleDragEnd,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (revealPreviousPage) ...[
                  IgnorePointer(
                    child: Transform.translate(
                      offset: Offset(
                        -viewportWidth * 0.22 * (1 - progress),
                        0,
                      ),
                      child: widget.previousPage,
                    ),
                  ),
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: 0.08 * (1 - progress),
                      ),
                    ),
                  ),
                ],
                Transform.translate(
                  offset: Offset(dragOffset, 0),
                  child: DecoratedBox(
                    decoration: revealPreviousPage
                        ? BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 14,
                                offset: Offset(-4, 0),
                              ),
                            ],
                          )
                        : const BoxDecoration(),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
