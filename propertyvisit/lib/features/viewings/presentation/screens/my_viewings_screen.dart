import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/property_photo.dart';
import '../../../auth/presentation/auth_cubit.dart';
import '../../data/viewing_repository.dart';
import '../../domain/viewing.dart';
import '../viewings_cubit.dart';
import '../widgets/status_chip.dart';

class MyViewingsScreen extends StatelessWidget {
  const MyViewingsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MyViewingsCubit(
      context.read<ViewingRepository>(),
      buyerId: context.read<AuthCubit>().state.user!.id,
    )..load(),
    child: Scaffold(
      appBar: AppBar(title: const Text('Мои просмотры')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ContentWidth(
          child: BlocConsumer<MyViewingsCubit, ViewingsState>(
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
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              if (state.status == ViewingsStatus.failure) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.error ?? 'Не удалось загрузить просмотры',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () =>
                              context.read<MyViewingsCubit>().load(),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (state.items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Пока нет записей на просмотр',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Выберите квартиру и удобное время. Здесь появятся детали вашей встречи.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: () =>
                              context.read<MyViewingsCubit>().load(),
                          child: const Text('Обновить'),
                        ),
                        FilledButton(
                          onPressed: () => context.go('/catalog'),
                          child: const Text('Выбрать квартиру'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return RefreshIndicator.adaptive(
                onRefresh: () => context.read<MyViewingsCubit>().load(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (context, index) => _ViewingCard(
                    viewing: state.items[index],
                    onCancel: (id) =>
                        context.read<MyViewingsCubit>().cancel(id),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ViewingCard extends StatelessWidget {
  const _ViewingCard({required this.viewing, required this.onCancel});
  final Viewing viewing;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canCancel =
        context.read<ViewingRepository>().supportsBuyerCancellation &&
        (viewing.status == ViewingStatus.pending ||
            viewing.status == ViewingStatus.confirmed);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(status: viewing.status),
            const SizedBox(height: 12),
            Text(
              formatViewingRange(viewing.startsAtUtc),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: PropertyPhoto(source: viewing.propertyPhotoUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewing.propertyTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        viewing.propertyAddress,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canCancel) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () async {
                    final confirmed = await showAdaptiveDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog.adaptive(
                        title: const Text('Отменить просмотр?'),
                        content: Text(
                          '${viewing.propertyTitle}\n${formatViewingRange(viewing.startsAtUtc)}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Оставить запись'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Отменить просмотр'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) onCancel(viewing.id);
                  },
                  child: const Text('Отменить просмотр'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
