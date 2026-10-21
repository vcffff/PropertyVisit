import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propertyvisit/core/data/mock_store.dart';
import 'package:propertyvisit/core/widgets/property_image_widget.dart';
import 'package:propertyvisit/features/properties/data/property_repository.dart';
import 'package:propertyvisit/features/properties/domain/property.dart';
import 'package:propertyvisit/features/properties/presentation/screens/property_details_screen.dart';

import 'api_integration_test.dart' as fixtures;

const cover =
    'https://example.supabase.co/storage/v1/object/public/property-images/properties/2/first.png';
Map<String, dynamic> propertyJson({String? url = cover}) => {
  'id': 2,
  'title': 'Apartment',
  'address': 'Astana',
  'price': 45000000,
  'cover_image_url': url,
};
Map<String, dynamic> imageJson(int id, String url, int position) => {
  'id': id,
  'url': url,
  'position': position,
  'content_type': 'image/png',
};

class _GalleryRepository extends MockPropertyRepository {
  _GalleryRepository() : super(MockStore.seed());

  @override
  Future<Property> getProperty(String id) async => Property.fromJson({
    ...propertyJson(),
    'images': List.generate(
      10,
      (i) => imageJson(i + 1, 'assets/properties/interior-${i % 6 + 1}.jpg', i),
    ),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'catalog maps stable cover URL; old/null responses keep the fallback',
    () {
      final property = Property.fromJson(propertyJson());
      expect(property.photoUrl, cover);
      expect(property.images, isEmpty);
      expect(Property.fromJson(propertyJson(url: null)).photoUrl, isEmpty);
      expect(
        Property.fromJson(propertyJson()..remove('cover_image_url')).photoUrl,
        isEmpty,
      );
    },
  );

  test(
    'details preserve ordered image metadata, empty URLs and empty galleries',
    () {
      final property = Property.fromJson({
        ...propertyJson(),
        'images': [imageJson(10, cover, 0), imageJson(12, '', 4)],
      });
      expect(property.images.map((image) => image.id), [10, 12]);
      expect(property.images.last.position, 4);
      expect(property.images.last.contentType, 'image/png');
      expect(property.images.last.url, isEmpty);
      expect(() => property.images.clear(), throwsUnsupportedError);
      expect(
        Property.fromJson({...propertyJson(url: null), 'images': []}).images,
        isEmpty,
      );
      expect(property, isNot(Property.fromJson(propertyJson())));
    },
  );

  test(
    'catalog never supplies a detail gallery; reopening reuses details; explicit refresh discovers replacements',
    () async {
      var listCalls = 0, detailCalls = 0;
      var currentCover = cover;
      final client = fixtures.clientWith((request) {
        if (request.path == '/properties') {
          listCalls++;
          return fixtures.jsonResponse([propertyJson(url: currentCover)]);
        }
        expect(request.path, '/properties/2');
        detailCalls++;
        return fixtures.jsonResponse({
          ...propertyJson(url: currentCover),
          'images': [
            imageJson(10, currentCover, 0),
            imageJson(11, '$cover-second', 1),
          ],
        });
      });
      final repo = ApiPropertyRepository(client);
      expect((await repo.getProperties()).single.images, isEmpty);
      expect(detailCalls, 0);
      final details = await repo.getProperty('2');
      expect(details.images, hasLength(2));
      expect(await repo.getProperty('2'), same(details));
      expect(detailCalls, 1);
      expect(listCalls, 1);
      currentCover = '$cover-replacement';
      expect((await repo.getProperties()).single.photoUrl, currentCover);
      expect((await repo.getProperty('2')).images.first.url, currentCover);
      expect(detailCalls, 2);
      expect(listCalls, 2);
      client.dio.close();
      client.authDio.close();
    },
  );

  testWidgets(
    'detail gallery is lazy, fixed-size and navigable with Chrome-friendly buttons',
    (tester) async {
      await tester.pumpWidget(
        RepositoryProvider<PropertyRepository>(
          create: (_) => _GalleryRepository(),
          child: const MaterialApp(
            home: PropertyDetailsScreen(propertyId: '2'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 10'), findsOneWidget);
      expect(find.byType(PropertyImageWidget).evaluate().length, lessThan(10));
      final initialSize = tester.getSize(find.byType(PageView));
      await tester.tap(find.byTooltip('Следующее фото'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 10'), findsOneWidget);
      expect(tester.getSize(find.byType(PageView)), initialSize);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
