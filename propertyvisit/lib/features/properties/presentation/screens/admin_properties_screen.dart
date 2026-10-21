import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/logout_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/property_repository.dart';
import '../properties_cubit.dart';
import 'catalog_screen.dart' show PropertyCard;

class AdminPropertiesScreen extends StatelessWidget {
  const AdminPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PropertiesCubit(context.read<PropertyRepository>())..load(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Квартиры'),
            actions: const [LogoutButton()],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.surface,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Добавить'),
            onPressed: () =>
                _showCreateDialog(context, context.read<PropertiesCubit>()),
          ),
          body: ContentWidth(
            child: BlocConsumer<PropertiesCubit, PropertiesState>(
              listener: (context, state) {
                if (state.status == PropertiesStatus.ready &&
                    state.error != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.error!)));
                }
              },
              builder: (context, state) {
                if (state.status == PropertiesStatus.loading) {
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  );
                }
                if (state.status == PropertiesStatus.failure ||
                    state.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.error ?? 'Объектов пока нет',
                          textAlign: TextAlign.center,
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              context.read<PropertiesCubit>().refresh(),
                          child: const Text('Обновить'),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => context.read<PropertiesCubit>().refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 20),
                    itemBuilder: (context, index) =>
                        PropertyCard(property: state.items[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    PropertiesCubit cubit,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreatePropertyDialog(cubit: cubit),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Квартира добавлена')));
    }
  }
}

class _CreatePropertyDialog extends StatefulWidget {
  const _CreatePropertyDialog({required this.cubit});

  final PropertiesCubit cubit;

  @override
  State<_CreatePropertyDialog> createState() => _CreatePropertyDialogState();
}

class _CreatePropertyDialogState extends State<_CreatePropertyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Астана');
  final _price = TextEditingController();
  final _rooms = TextEditingController(text: '2');
  final _area = TextEditingController();
  final _description = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _title,
      _address,
      _city,
      _price,
      _rooms,
      _area,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.cubit.create(
      title: _title.text.trim(),
      address: _address.text.trim(),
      city: context.read<AuthRepository>().isDemo ? _city.text.trim() : '',
      price: int.parse(_price.text.trim().replaceAll(RegExp(r'\s'), '')),
      rooms: context.read<AuthRepository>().isDemo
          ? int.parse(_rooms.text.replaceAll(RegExp(r'\s'), ''))
          : 0,
      area: context.read<AuthRepository>().isDemo
          ? double.parse(_area.text.trim().replaceAll(',', '.'))
          : 0,
      description: _description.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error =
            'Не удалось сохранить квартиру. Данные сохранены в форме. Перед повтором обновите каталог: сервер мог уже создать объект.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая квартира'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'ЖК / название'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Заполните поле' : null,
              ),
              const SizedBox(height: 12),
              if (context.read<AuthRepository>().isDemo)
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'Город'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Заполните поле' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Адрес'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Заполните поле' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Цена, ₸'),
                validator: positiveInteger,
              ),
              const SizedBox(height: 12),
              if (context.read<AuthRepository>().isDemo)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rooms,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Комнат'),
                        validator: positiveInteger,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _area,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Площадь, м²',
                        ),
                        validator: positiveArea,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (context.read<AuthRepository>().isDemo)
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}
