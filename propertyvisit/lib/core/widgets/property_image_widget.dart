import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Public property photos only. API JSON and credentials never enter this cache.
class PropertyImageCache {
  PropertyImageCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'propertyPhotosV1',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );

  // Shared width buckets limit decoded-image variants while retaining DPR detail.
  static const decodeWidths = [256, 512, 768, 1024, 1536];

  /// Call only after a confirmed replacement at the SAME URL, then remount the
  /// affected widget with a new key. New object/version URLs have a new cache key.
  static Future<void> invalidate(
    String url, {
    BaseCacheManager? cacheManager,
  }) async {
    final source = url.trim();
    if (source.isEmpty || source.startsWith('assets/')) return;
    final manager = cacheManager ?? instance;
    final provider = CachedNetworkImageProvider(source, cacheManager: manager);
    for (final width in decodeWidths) {
      await ResizeImage.resizeIfNeeded(width, null, provider).evict();
    }
    await CachedNetworkImage.evictFromCache(source, cacheManager: manager);
  }
}

/// Stable-size property photo shared by catalog, details, history and admin.
/// Bundled demo assets remain illustrative, not verified listing photographs.
class PropertyImageWidget extends StatelessWidget {
  const PropertyImageWidget({
    super.key,
    required this.source,
    this.label,
    this.aspectRatio = 1.85,
    this.borderRadius = BorderRadius.zero,
    this.cacheManager,
  });

  final String? source;
  final String? label;
  final double aspectRatio;
  final BorderRadius borderRadius;
  // Optional injection for isolated tests; production callers share the singleton.
  final BaseCacheManager? cacheManager;

  @override
  Widget build(BuildContext context) {
    final url = source?.trim() ?? '';
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pixels =
                constraints.maxWidth * MediaQuery.devicePixelRatioOf(context);
            final width = PropertyImageCache.decodeWidths.firstWhere(
              (width) => width >= pixels,
              orElse: () => PropertyImageCache.decodeWidths.last,
            );
            if (url.isEmpty) return const _UnavailablePhoto();
            return Semantics(
              label:
                  label ??
                  (url.startsWith('assets/')
                      ? 'Иллюстративное фото квартиры'
                      : 'Фото объекта'),
              image: true,
              child: ExcludeSemantics(
                child: url.startsWith('assets/')
                    ? Image.asset(
                        url,
                        fit: BoxFit.cover,
                        cacheWidth: width,
                        errorBuilder: (_, _, _) => const _UnavailablePhoto(),
                      )
                    : CachedNetworkImage(
                        // Do not append timestamps or strip signed URL tokens.
                        imageUrl: url,
                        cacheManager:
                            cacheManager ?? PropertyImageCache.instance,
                        memCacheWidth: width,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        filterQuality: FilterQuality.low,
                        fadeInDuration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, _) =>
                            ColoredBox(color: colors.surfaceContainerHighest),
                        errorWidget: (_, _, _) => const _UnavailablePhoto(),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UnavailablePhoto extends StatelessWidget {
  const _UnavailablePhoto();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primaryContainer,
      child: Semantics(
        label: 'Фото недоступно',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final icon = Icon(
              LucideIcons.imageOff,
              color: colors.onPrimaryContainer,
            );
            return Center(
              child: constraints.maxWidth < 120 || constraints.maxHeight < 120
                  ? icon
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(height: 8),
                        Text(
                          'Фото недоступно',
                          style: TextStyle(color: colors.onPrimaryContainer),
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
