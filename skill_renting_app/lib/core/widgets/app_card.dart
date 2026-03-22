import 'package:flutter/material.dart';

/// Consistent card styling across the app.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final int elevation;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 12,
    this.elevation = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.surface;
    return Card(
      color: c,
      elevation: elevation.toDouble(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}

