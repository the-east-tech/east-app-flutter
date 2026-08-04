import 'package:flutter/material.dart';

class EastLogo extends StatelessWidget {
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  const EastLogo({
    super.key,
    this.size = 48,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.backgroundColor,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(size * 0.22),
      ),
      child: Image.asset(
        'assets/app_icon.png',
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Icon(
          Icons.restaurant_rounded,
          size: size * .56,
          color: Colors.white,
        ),
      ),
    );
  }
}
