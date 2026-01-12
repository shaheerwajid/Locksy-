import 'package:flutter/material.dart';

class BlinkIcon extends StatefulWidget {
  final IconData icono;
  final Color color;
  const BlinkIcon({super.key, required this.icono, required this.color});
  @override
  _BlinkIconState createState() => _BlinkIconState();
}

class _BlinkIconState extends State<BlinkIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  late IconData icono;
  late Color color;
  @override
  void initState() {
    icono = widget.icono;
    color = widget.color;
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _colorAnimation = ColorTween(begin: color, end: Colors.white)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
      setState(() {});
    });
    _controller.forward();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Icon(
          icono,
          // size: 128,
          color: _colorAnimation.value,
        );
      },
    );
  }
}
