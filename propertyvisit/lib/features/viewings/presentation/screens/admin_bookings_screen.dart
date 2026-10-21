import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/logout_button.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/viewing_repository.dart';
import '../../domain/viewing.dart';
import '../viewings_cubit.dart';
import '../widgets/status_chip.dart';

class AdminBookingsScreen extends StatelessWidget {
  const AdminBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Бронирования'),
        actions: const [LogoutButton()],
      ),
      body: ContentWidth(
        child: BlocProvider(
          create: (_) =>
              AdminViewingsCubit(context.read<ViewingRepository>())..load(),
          child: BlocConsumer<AdminViewingsCubit, ViewingsState>(
            listener: (context, state) {
              if (state.error != null && state.status == ViewingsStatus.ready) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.error!)));
              }
            },
            builder: (context, state) {
              if (state.status == ViewingsStatus.loading) {
                return const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                );
              }
              if (state.status == ViewingsStatus.failure) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.error ?? 'Ошибка',
                        textAlign: TextAlign.center,
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            context.read<AdminViewingsCubit>().load(),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                );
              }
              if (state.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Бронирований пока нет'),
                      OutlinedButton(
                        onPressed: () =>
                            context.read<AdminViewingsCubit>().load(),
                        child: const Text('Обновить'),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => context.read<AdminViewingsCubit>().load(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _AdminViewingCard(
                    viewing: state.items[index],
                    busy: state.updatingIds.contains(state.items[index].id),
                    onConfirm: (id) => context
                        .read<AdminViewingsCubit>()
                        .setStatus(id, ViewingStatus.confirmed),
                    onCancel: (id) => context
                        .read<AdminViewingsCubit>()
                        .setStatus(id, ViewingStatus.cancelled),
                    onComplete: (id) => context
                        .read<AdminViewingsCubit>()
                        .setStatus(id, ViewingStatus.completed),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminViewingCard extends StatelessWidget {
  const _AdminViewingCard({
    required this.viewing,
    required this.onConfirm,
    required this.onCancel,
    required this.onComplete,
    required this.busy,
  });

  final Viewing viewing;
  final ValueChanged<String> onConfirm;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onComplete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  viewing.propertyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                StatusChip(status: viewing.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatViewingRange(viewing.startsAtUtc),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Icon(
                  LucideIcons.userRound,
                  size: 18,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  viewing.buyerName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (viewing.hasBuyerContact)
                  const Icon(
                    LucideIcons.phone,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                const SizedBox(width: 8),
                Text(
                  viewing.buyerPhone,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (viewing.status == ViewingStatus.pending ||
                viewing.status == ViewingStatus.confirmed) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (viewing.status == ViewingStatus.pending)
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : () => onConfirm(viewing.id),
                        child: const Text('Подтвердить'),
                      ),
                    ),
                  if (viewing.status == ViewingStatus.pending)
                    const SizedBox(width: 10),
                  if (viewing.status == ViewingStatus.confirmed)
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : () => onComplete(viewing.id),
                        child: const Text('Завершить'),
                      ),
                    ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => onCancel(viewing.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cancelled,
                        side: const BorderSide(color: AppColors.cancelled),
                      ),
                      child: const Text('Отменить'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
