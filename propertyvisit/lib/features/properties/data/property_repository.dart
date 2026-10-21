import '../../../core/data/mock_store.dart';
import '../../../core/network/api_client.dart';
import '../domain/property.dart';

abstract class PropertyRepository {
  Future<List<Property>> getProperties();
  Future<Property> getProperty(String id);

  Future<Property> create({
    required String title,
    required String address,
    required String city,
    required int price,
    required int rooms,
    required double area,
    required String description,
  });
}

class ApiPropertyRepository implements PropertyRepository {
  ApiPropertyRepository(this.client);
  final ApiClient client;
  final Map<String, Property> _cache = {};
  // Catalog summaries must not satisfy a request for the detail gallery.
  final Map<String, Property> _detailsCache = {};
  Future<List<Property>>? _pendingList;
  final Map<String, Future<Property>> _pendingDetails = {};
  Property? cached(String id) => _cache[id];
  Property _remember(Map<String, dynamic> json) {
    final property = Property.fromJson(json);
    _cache[property.id] = property;
    return property;
  }

  @override
  Future<List<Property>> getProperties() => _pendingList ??= _fetchProperties()
      .whenComplete(() => _pendingList = null);

  Future<List<Property>> _fetchProperties() async {
    final response = await client.dio.get<List<dynamic>>('/properties');
    // Explicit catalog refresh also makes the next detail visit fetch new media.
    _detailsCache.clear();
    return response.data!
        .map((e) => _remember(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Property> getProperty(String id) {
    final cached = _detailsCache[id];
    if (cached != null) return Future.value(cached);
    return _pendingDetails.putIfAbsent(
      id,
      () => _fetchProperty(id).whenComplete(() {
        _pendingDetails.remove(id);
      }),
    );
  }

  Future<Property> _fetchProperty(String id) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/properties/$id',
    );
    final property = _remember(response.data!);
    _detailsCache[id] = property;
    return property;
  }

  @override
  Future<Property> create({
    required String title,
    required String address,
    required String city,
    required int price,
    required int rooms,
    required double area,
    required String description,
  }) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      '/properties',
      data: {'title': title, 'address': address, 'price': price},
    );
    return _remember(response.data!);
  }
}

class MockPropertyRepository implements PropertyRepository {
  MockPropertyRepository(this._store);

  final MockStore _store;

  @override
  Future<List<Property>> getProperties() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_store.properties);
  }

  @override
  Future<Property> getProperty(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _store.properties.firstWhere((p) => p.id == id);
  }

  @override
  Future<Property> create({
    required String title,
    required String address,
    required String city,
    required int price,
    required int rooms,
    required double area,
    required String description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final property = Property(
      id: _store.nextPropertyId(),
      title: title,
      address: address,
      city: city,
      price: price,
      rooms: rooms,
      area: area,
      photoUrl: '',
      description: description,
    );
    _store.properties.insert(0, property);
    return property;
  }
}
