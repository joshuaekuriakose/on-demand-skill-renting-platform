import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final EdgeInsetsGeometry? padding;
  const StatusChip({super.key, required this.status, this.padding});

  Color _colorFor(String s) {
    switch (s) {
      case "accepted":    return const Color(0xFF60A5FA);
      case "in_progress": return const Color(0xFFA78BFA);
      case "completed":   return const Color(0xFF34D399);
      case "rejected":    return const Color(0xFFF87171);
      case "cancelled":   return const Color(0xFF9CA3AF);
      case "requested":   return const Color(0xFFFBBF24);
      default:            return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        status.replaceAll("_", " ").toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}
