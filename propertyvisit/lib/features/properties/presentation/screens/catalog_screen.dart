import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/property_image_widget.dart';
import '../../../auth/presentation/auth_cubit.dart';
import '../../data/property_repository.dart';
import '../../domain/property.dart';
import '../properties_cubit.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PropertiesCubit(context.read<PropertyRepository>())..load(),
    child: const _CatalogView(),
  );
}

enum _Sort { priceLow, priceHigh, area }

class _CatalogView extends StatefulWidget {
  const _CatalogView();
  @override
  State<_CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<_CatalogView> {
  final _search = TextEditingController();
  String _city = '';
  int _rooms = 0;
  _Sort _sort = _Sort.priceLow;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _search.clear();
    _city = '';
    _rooms = 0;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        foregroundColor: Colors.white,
        title: Text(
          'Каталог',
          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        toolbarHeight: 76,
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () async {
              final logout = await showAdaptiveDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog.adaptive(
                  title: const Text('Выйти из аккаунта?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Выйти'),
                    ),
                  ],
                ),
              );
              if (logout == true && context.mounted) {
                context.read<AuthCubit>().logout();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ColoredBox(
              color: AppColors.header,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: ContentWidth(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Город, адрес или ЖК',
                      prefixIcon: const Icon(LucideIcons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Очистить поиск',
                              icon: const Icon(LucideIcons.x),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
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
                  final hasDetails = state.items.any(
                    (p) => p.hasExtendedDetails,
                  );
                  final cities =
                      state.items
                          .map((p) => p.city)
                          .where((s) => s.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort();
                  final query = _search.text.trim().toLowerCase();
                  final items = state.items
                      .where(
                        (p) =>
                            (_city.isEmpty || p.city == _city) &&
                            (_rooms == 0 || p.rooms == _rooms) &&
                            '${p.title} ${p.city} ${p.address}'
                                .toLowerCase()
                                .contains(query),
                      )
                      .toList();
                  items.sort(
                    (a, b) => switch (_sort) {
                      _Sort.priceLow => a.price.compareTo(b.price),
                      _Sort.priceHigh => b.price.compareTo(a.price),
                      _Sort.area => b.area.compareTo(a.area),
                    },
                  );
                  return ContentWidth(
                    child: Column(
                      children: [
                        if (hasDetails)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _FilterMenu<String>(
                                    label: _city.isEmpty ? 'Все города' : _city,
                                    selected: _city,
                                    entries: {
                                      '': 'Все города',
                                      for (final city in cities) city: city,
                                    },
                                    onChanged: (value) =>
                                        setState(() => _city = value),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _FilterMenu<int>(
                                    label: _rooms == 0
                                        ? 'Комнаты'
                                        : '$_rooms комн.',
                                    selected: _rooms,
                                    entries: const {
                                      0: 'Любое количество',
                                      1: '1 комната',
                                      2: '2 комнаты',
                                      3: '3 комнаты',
                                    },
                                    onChanged: (value) =>
                                        setState(() => _rooms = value),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                        if (state.status == PropertiesStatus.loading)
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          )
                        else if (state.status == PropertiesStatus.failure)
                          Expanded(
                            child: _Message(
                              title: 'Не удалось загрузить каталог',
                              detail:
                                  state.error ??
                                  'Проверьте подключение и попробуйте снова.',
                              action: 'Повторить',
                              onAction: () =>
                                  context.read<PropertiesCubit>().refresh(),
                            ),
                          )
                        else
                          Expanded(
                            child: RefreshIndicator.adaptive(
                              onRefresh: () =>
                                  context.read<PropertiesCubit>().refresh(),
                              child: CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        8,
                                        16,
                                        8,
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 12,
                                        children: [
                                          Text(
                                            'Объекты: ${items.length}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          PopupMenuButton<_Sort>(
                                            tooltip: 'Сортировка',
                                            initialValue: _sort,
                                            onSelected: (value) =>
                                                setState(() => _sort = value),
                                            itemBuilder: (_) => [
                                              PopupMenuItem(
                                                value: _Sort.priceLow,
                                                child: Text('Сначала дешевле'),
                                              ),
                                              PopupMenuItem(
                                                value: _Sort.priceHigh,
                                                child: Text('Сначала дороже'),
                                              ),
                                              if (hasDetails)
                                                const PopupMenuItem(
                                                  value: _Sort.area,
                                                  child: Text(
                                                    'Сначала просторнее',
                                                  ),
                                                ),
                                            ],
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    switch (_sort) {
                                                      _Sort.priceLow =>
                                                        'По цене ↑',
                                                      _Sort.priceHigh =>
                                                        'По цене ↓',
                                                      _Sort.area =>
                                                        'По площади ↓',
                                                    },
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    LucideIcons.arrowDownUp,
                                                    size: 18,
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (items.isEmpty)
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: _Message(
                                        title: 'Ничего не найдено',
                                        detail:
                                            'Попробуйте другой адрес или измените фильтры.',
                                        action: 'Сбросить поиск',
                                        onAction: _reset,
                                      ),
                                    )
                                  else
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        0,
                                        24,
                                        24,
                                      ),
                                      sliver: SliverList.separated(
                                        itemCount: items.length,
                                        separatorBuilder: (_, _) =>
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 24,
                                              ),
                                              child: Divider(),
                                            ),
                                        itemBuilder: (context, index) =>
                                            PropertyCard(
                                              property: items[index],
                                              onTap: () => context.push(
                                                '/catalog/property/${items[index].id}',
                                              ),
                                            ),
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
          ],
        ),
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.selected,
    required this.entries,
    required this.onChanged,
  });
  final String label;
  final T selected;
  final Map<T, String> entries;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: label,
    initialValue: selected,
    onSelected: onChanged,
    itemBuilder: (_) => entries.entries
        .map(
          (e) => CheckedPopupMenuItem<T>(
            value: e.key,
            checked: e.key == selected,
            child: Text(e.value),
          ),
        )
        .toList(),
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 2)),
          const Icon(LucideIcons.chevronDown, size: 20),
        ],
      ),
    ),
  );
}

class PropertyCard extends StatelessWidget {
  const PropertyCard({super.key, required this.property, this.onTap});
  final Property property;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PropertyImageWidget(
              source: property.photoUrl,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 16),
            Text(
              formatPrice(property.price),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(property.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(property.displayAddress, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (property.hasExtendedDetails)
              Text(
                '${property.rooms} комн · ${formatArea(property.area)} м²',
                style: theme.textTheme.bodyMedium,
              ),
            if (property.photoUrl.startsWith('assets/')) ...[
              const SizedBox(height: 8),
              Text(
                'Демо-объект · фото для примера',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String formatArea(double area) => area.truncateToDouble() == area
    ? area.toStringAsFixed(0)
    : area.toStringAsFixed(1);

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.detail,
    required this.action,
    required this.onAction,
  });
  final String title, detail, action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );
}
