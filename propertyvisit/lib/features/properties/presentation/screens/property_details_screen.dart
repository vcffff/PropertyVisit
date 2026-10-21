import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/property_image_widget.dart';
import '../../data/property_repository.dart';
import '../../domain/property.dart';
import 'catalog_screen.dart' show formatArea;
import '../../../../core/network/api_client.dart';

class PropertyDetailsScreen extends StatefulWidget {
  const PropertyDetailsScreen({super.key, required this.propertyId});
  final String propertyId;
  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  late Future<Property> _property;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _property = context.read<PropertyRepository>().getProperty(
      widget.propertyId,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Property>(
    future: _property,
    builder: (context, snapshot) {
      final theme = Theme.of(context);
      final property = snapshot.data;
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text('Об объекте')),
        body: snapshot.hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        apiErrorMessage(snapshot.error!),
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => setState(_load),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            : property == null
            ? const Center(child: CircularProgressIndicator.adaptive())
            : SafeArea(
                top: false,
                bottom: false,
                child: ContentWidth(
                  child: ListView(
                    children: [
                      _PropertyGallery(
                        key: ValueKey(property.id),
                        property: property,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (property.photoUrl.startsWith('assets/')) ...[
                              Text(
                                'Демо-объект · иллюстративное фото',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              formatPrice(property.price),
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              property.title,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              property.displayAddress,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (property.hasExtendedDetails) ...[
                              const SizedBox(height: 28),
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Wrap(
                                  spacing: 40,
                                  runSpacing: 20,
                                  children: [
                                    _Fact(
                                      value: '${property.rooms}',
                                      label: 'Комнаты',
                                    ),
                                    _Fact(
                                      value: '${formatArea(property.area)} м²',
                                      label: 'Площадь',
                                    ),
                                    _Fact(
                                      value:
                                          property.area.isFinite &&
                                              property.area > 0 &&
                                              (property.price / property.area)
                                                  .isFinite
                                          ? formatPrice(
                                              (property.price / property.area)
                                                  .round(),
                                            )
                                          : '—',
                                      label: 'За м²',
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              const SizedBox(height: 28),
                              Text(
                                'Об объекте',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                property.description,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: property == null
            ? null
            : BookingBottomBar(propertyId: widget.propertyId),
      );
    },
  );
}

class _PropertyGallery extends StatefulWidget {
  const _PropertyGallery({super.key, required this.property});
  final Property property;

  @override
  State<_PropertyGallery> createState() => _PropertyGalleryState();
}

class _PropertyGalleryState extends State<_PropertyGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.property.images;
    if (images.isEmpty) {
      return PropertyImageWidget(
        aspectRatio: 1.3,
        source: widget.property.photoUrl,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1.3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => PropertyImageWidget(
              key: ValueKey(images[index].id),
              source: images[index].url,
              aspectRatio: 1.3,
              label: 'Фото объекта ${index + 1} из ${images.length}',
            ),
          ),
          if (images.length > 1) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filledTonal(
                  tooltip: 'Предыдущее фото',
                  onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
                  icon: const Icon(LucideIcons.chevronLeft),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filledTonal(
                  tooltip: 'Следующее фото',
                  onPressed: _page < images.length - 1
                      ? () => _goTo(_page + 1)
                      : null,
                  icon: const Icon(LucideIcons.chevronRight),
                ),
              ),
            ),
          ],
          if (images.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Semantics(
                liveRegion: true,
                label: 'Фото ${_page + 1} из ${images.length}',
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '${_page + 1} / ${images.length}',
                        style: TextStyle(color: colors.onSurface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class BookingBottomBar extends StatelessWidget {
  const BookingBottomBar({super.key, required this.propertyId});
  final String propertyId;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: ContentWidth(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  context.push('/catalog/property/$propertyId/book'),
              child: const Text('Записаться на просмотр'),
            ),
          ),
        ),
      ),
    ),
  );
}
