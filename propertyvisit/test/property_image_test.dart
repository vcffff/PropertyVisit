import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:propertyvisit/core/widgets/property_image_widget.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _Photos extends FileService {
  int downloads = 0;
  final urls = <String>[];
  Completer<void>? gate;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    downloads++;
    urls.add(url);
    expect(headers?.containsKey('Authorization') ?? false, isFalse);
    await gate?.future;
    return _Response(url.endsWith('broken') ? 404 : 200);
  }
}

class _Response implements FileServiceResponse {
  _Response(this.statusCode);
  @override
  final int statusCode;
  @override
  Stream<List<int>> get content => Stream.value(_png);
  @override
  int get contentLength => _png.length;
  @override
  String get fileExtension => '.png';
  @override
  String get eTag => 'photo-v1';
  @override
  DateTime get validTill => DateTime.now().add(const Duration(hours: 1));
}

class _WidgetPhotos implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => url.endsWith('broken')
      ? Stream.error(
          HttpExceptionWithStatus(404, 'Missing photo', uri: Uri.parse(url)),
        )
      : const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late CacheManager manager;
  late _Photos photos;
  const url =
      'https://example.supabase.co/storage/v1/object/public/photos/one.png';

  setUp(() async {
    final temporaryRoot = Directory('${Directory.systemTemp.path}/opencode');
    await temporaryRoot.create(recursive: true);
    directory = await temporaryRoot.createTemp('property-image-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    photos = _Photos();
    manager = CacheManager(
      Config(
        'testPhotos',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
        repo: JsonCacheInfoRepository(path: '${directory.path}/metadata.json'),
        fileService: photos,
      ),
    );
    // Finish eager filesystem initialization before widget fake clocks start.
    await manager.config.fileSystem.createFile('initialized');
  });

  tearDown(() async {
    await manager.emptyCache();
    await manager.dispose();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await directory.delete(recursive: true);
  });

  test(
    'first load, concurrent requests and reopening reuse one disk file',
    () async {
      photos.gate = Completer<void>();
      final a = manager.getFileStream(url).toList();
      final b = manager.getFileStream(url).toList();
      photos.gate!.complete();
      await Future.wait([a, b]);
      expect(photos.downloads, 1);
      final file = await manager.getSingleFile(url);
      expect(await file.readAsBytes(), _png);
      expect(photos.downloads, 1);
    },
  );

  test(
    'replaced URL downloads once; same-URL replacement evicts disk and resized memory',
    () async {
      final provider = ResizeImage.resizeIfNeeded(
        512,
        null,
        CachedNetworkImageProvider(url, cacheManager: manager),
      );
      final completer = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (_, _) => completer.complete(),
        onError: (Object e, StackTrace? s) => completer.completeError(e, s),
      );
      stream.addListener(listener);
      await completer.future;
      stream.removeListener(listener);
      expect(
        await provider.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ),
        isNotNull,
      );
      await PropertyImageCache.invalidate(url, cacheManager: manager);
      expect(
        (await provider.obtainCacheStatus(
          configuration: ImageConfiguration.empty,
        ))!.untracked,
        isTrue,
      );
      expect(await manager.getFileFromCache(url), isNull);
      await manager.getSingleFile(url);
      await manager.getSingleFile('$url?v=2');
      await manager.getSingleFile('$url?v=2');
      expect(photos.downloads, 3);
    },
  );

  testWidgets('missing URL has a stable crop and no network request', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 370, child: PropertyImageWidget(source: null)),
        ),
      ),
    );
    expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
    expect(
      tester.getSize(find.byType(PropertyImageWidget)),
      const Size(370, 200),
    );
    expect(photos.downloads, 0);
  });

  testWidgets(
    'loading, broken URL and changed URL keep geometry and shared configuration',
    (tester) async {
      final widgetManager = _WidgetPhotos();
      Future<void> show(String source) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 370,
              child: PropertyImageWidget(
                source: source,
                cacheManager: widgetManager,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );
      await show('$url/broken');
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.cacheManager, same(widgetManager));
      expect(image.memCacheWidth, lessThanOrEqualTo(1536));
      expect(image.fit, BoxFit.cover);
      expect(image.imageUrl, '$url/broken');
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
      expect(
        tester.getSize(find.byType(PropertyImageWidget)),
        const Size(370, 200),
      );
      await show('$url?v=2');
      expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .imageUrl,
        '$url?v=2',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
