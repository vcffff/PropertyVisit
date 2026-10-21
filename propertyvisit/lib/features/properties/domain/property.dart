import 'package:equatable/equatable.dart';

class PropertyImage extends Equatable {
  const PropertyImage({
    required this.id,
    required this.url,
    required this.position,
    required this.contentType,
  });

  final int id;
  final String url;
  final int position;
  final String contentType;

  factory PropertyImage.fromJson(Map<String, dynamic> json) => PropertyImage(
    id: json['id'] as int,
    url: json['url'] as String? ?? '',
    position: json['position'] as int,
    contentType: json['content_type'] as String,
  );

  @override
  List<Object?> get props => [id, url, position, contentType];
}

class Property extends Equatable {
  const Property({
    required this.id,
    required this.title,
    required this.address,
    required this.city,
    required this.price,
    required this.rooms,
    required this.area,
    required this.photoUrl,
    required this.description,
    this.hasExtendedDetails = true,
    this.images = const [],
  });

  final String id;
  final String title;
  final String address;
  final String city;

  /// Price in tenge.
  final int price;
  final int rooms;
  final double area;
  final String photoUrl;

  /// Ordered gallery supplied by GET /properties/:id; absent in the catalog.
  final List<PropertyImage> images;
  final String description;
  final bool hasExtendedDetails;
  String get displayAddress =>
      [city, address].where((s) => s.isNotEmpty).join(', ');

  factory Property.fromJson(Map<String, dynamic> json) => Property(
    id: (json['id'] as int).toString(),
    title: json['title'] as String,
    address: json['address'] as String,
    price: json['price'] as int,
    city: '',
    rooms: 0,
    area: 0,
    photoUrl: json['cover_image_url'] as String? ?? '',
    images: List.unmodifiable(
      (json['images'] as List<dynamic>? ?? const []).map(
        (image) => PropertyImage.fromJson(image as Map<String, dynamic>),
      ),
    ),
    description: '',
    hasExtendedDetails: false,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    address,
    city,
    price,
    rooms,
    area,
    photoUrl,
    description,
    images,
    hasExtendedDetails,
  ];
}
