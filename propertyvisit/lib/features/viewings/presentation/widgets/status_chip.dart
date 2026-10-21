import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/viewing.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ViewingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      ViewingStatus.pending => (
        'Ожидает',
        AppColors.pending,
        AppColors.pendingSoft,
      ),
      ViewingStatus.confirmed => (
        'Подтверждён',
        AppColors.confirmed,
        AppColors.confirmedSoft,
      ),
      ViewingStatus.cancelled => (
        'Отменён',
        AppColors.cancelled,
        AppColors.cancelledSoft,
      ),
      ViewingStatus.completed => (
        'Завершён',
        AppColors.confirmed,
        AppColors.confirmedSoft,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
