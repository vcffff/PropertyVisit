import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/auth_cubit.dart';
import '../../../properties/data/property_repository.dart';
import '../../../properties/domain/property.dart';
import '../../domain/viewing.dart';
import '../booking_cubit.dart';
import '../widgets/status_chip.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, required this.propertyId});
  final String propertyId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        BookingCubit(context.read(), propertyId: propertyId)..loadDay(_today()),
    child: _BookingView(
      buyer: context.read<AuthCubit>().state.user!,
      propertyId: propertyId,
    ),
  );
}

DateTime _today() {
  // API dates use the Astana calendar; slot labels use the device timezone.
  final now = DateTime.now().toUtc().add(const Duration(hours: 5));
  return DateTime(now.year, now.month, now.day);
}

class _BookingView extends StatefulWidget {
  const _BookingView({required this.buyer, required this.propertyId});
  final User buyer;
  final String propertyId;
  @override
  State<_BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends State<_BookingView> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final Future<Property> _property;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.buyer.name);
    _phone = TextEditingController(text: widget.buyer.phone);
    _property = context.read<PropertyRepository>().getProperty(
      widget.propertyId,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<BookingCubit>().submit(
      buyerId: widget.buyer.id,
      buyerName: _name.text.trim(),
      buyerPhone: _phone.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Выберите время')),
      body: SafeArea(
        top: false,
        child: BlocConsumer<BookingCubit, BookingState>(
          listener: (context, state) {
            if (state.status == BookingStatus.failure && state.error != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
          builder: (context, state) {
            if (state.status == BookingStatus.success && state.booked != null) {
              return ContentWidth(child: _SuccessView(booked: state.booked!));
            }
            final day = state.day ?? _today();
            final submitting = state.status == BookingStatus.submitting;
            return ContentWidth(
              child: Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        children: [
                          FutureBuilder<Property>(
                            future: _property,
                            builder: (context, snapshot) => snapshot.hasData
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          snapshot.data!.title,
                                          style: theme.textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          snapshot.data!.displayAddress,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Text(
                            'Дата просмотра (Астана, UTC+05:00)',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height:
                                84 * MediaQuery.textScalerOf(context).scale(1),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 14,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final date = _today().add(
                                  Duration(days: index),
                                );
                                final selected = DateUtils.isSameDay(date, day);
                                const weekdays = [
                                  'пн',
                                  'вт',
                                  'ср',
                                  'чт',
                                  'пт',
                                  'сб',
                                  'вс',
                                ];
                                return Semantics(
                                  label: formatDay(date),
                                  selected: selected,
                                  child: ChoiceChip(
                                    selected: selected,
                                    showCheckmark: false,
                                    onSelected: submitting
                                        ? null
                                        : (_) => context
                                              .read<BookingCubit>()
                                              .loadDay(date),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(weekdays[date.weekday - 1]),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${date.day}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            formatDay(day),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Местное время · 30 минут',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          if (state.status == BookingStatus.loading)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            )
                          else if (state.slots.isEmpty &&
                              state.status == BookingStatus.failure)
                            OutlinedButton(
                              onPressed: () =>
                                  context.read<BookingCubit>().loadDay(day),
                              child: const Text('Загрузить время повторно'),
                            )
                          else ...[
                            if (!state.slots.any((slot) => slot.available))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'На эту дату свободного времени нет. Выберите другой день.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: state.slots
                                  .map(
                                    (slot) => ChoiceChip(
                                      label: Text(formatTime(slot.startLocal)),
                                      selected:
                                          slot.startUtcMs ==
                                          state.selectedUtcMs,
                                      showCheckmark: true,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 12,
                                      ),
                                      onSelected: !slot.available || submitting
                                          ? null
                                          : (_) => context
                                                .read<BookingCubit>()
                                                .select(slot),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 28),
                          if (context.read<AuthRepository>().isDemo) ...[
                            Text(
                              'Ваши данные',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _name,
                              enabled: !submitting,
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Имя',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Введите имя'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phone,
                              enabled: !submitting,
                              keyboardType: TextInputType.phone,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Телефон',
                              ),
                              validator: (value) =>
                                  (value ?? '')
                                          .replaceAll(RegExp(r'\D'), '')
                                          .length <
                                      10
                                  ? 'Введите номер телефона'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'Заявка получит статус «Ожидает» до подтверждения менеджером.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.selectedUtcMs != null) ...[
                            Text(
                              formatViewingRange(
                                DateTime.fromMillisecondsSinceEpoch(
                                  state.selectedUtcMs!,
                                  isUtc: true,
                                ),
                              ),
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton(
                            onPressed: state.selectedUtcMs == null || submitting
                                ? null
                                : _submit,
                            child: submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    state.selectedUtcMs == null
                                        ? 'Выберите время просмотра'
                                        : 'Подтвердить бронирование',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.booked});
  final Viewing booked;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              LucideIcons.circleCheck,
              color: theme.colorScheme.primary,
              size: 48,
            ),
            const SizedBox(height: 24),
            Text(
              'Просмотр забронирован',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              formatViewingRange(booked.startsAtUtc),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(booked.propertyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(booked.propertyAddress, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(status: ViewingStatus.pending),
            ),
            const SizedBox(height: 16),
            const Text(
              'Менеджер подтвердит вашу заявку. Статус можно проверить в разделе «Мои просмотры».',
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go('/my-viewings', extra: booked.id),
              child: const Text('Мои просмотры'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/catalog'),
              child: const Text('Вернуться в каталог'),
            ),
          ],
        ),
      ),
    );
  }
}
