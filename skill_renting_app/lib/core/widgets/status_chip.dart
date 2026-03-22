import 'package:flutter/material.dart';

/// Simple status-to-chip helper for booking-like status strings.
///
/// Expects statuses like: requested, accepted, in_progress, completed, rejected, cancelled.
class StatusChip extends StatelessWidget {
  final String status;
  final EdgeInsetsGeometry? padding;

  const StatusChip({
    super.key,
    required this.status,
    this.padding,
  });

  Color _colorFor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case "accepted":
        return scheme.primary;
      case "in_progress":
        return scheme.secondary;
      case "completed":
        return Colors.green.shade600;
      case "rejected":
        return Colors.red.shade600;
      case "cancelled":
        return scheme.outline;
      case "requested":
      default:
        return scheme.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context);
    final textColor = color.computeLuminance() > 0.45 ? Colors.black : Colors.white;

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll("_", " ").toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

