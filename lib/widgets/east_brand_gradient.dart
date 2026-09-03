import 'package:flutter/material.dart';

class EastBrandGradient {
  static const List<Color> colours = <Color>[
    Color(0xFF07011D),
    Color(0xFF1237B8),
    Color(0xFF7B2CFF),
  ];

  static LinearGradient at(double shift) {
    return LinearGradient(
      begin: Alignment(-1 + shift * .35, -1),
      end: Alignment(1, 1 - shift * .25),
      colors: colours,
    );
  }
}

class EastAnimatedGradientSurface extends StatefulWidget {
  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const EastAnimatedGradientSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
  });

  @override
  State<EastAnimatedGradientSurface> createState() =>
      _EastAnimatedGradientSurfaceState();
}

class _EastAnimatedGradientSurfaceState extends State<EastAnimatedGradientSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: EastBrandGradient.at(_controller.value),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
