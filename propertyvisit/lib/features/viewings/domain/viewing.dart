import 'package:equatable/equatable.dart';

enum ViewingStatus { pending, confirmed, cancelled, completed }

class Viewing extends Equatable {
  const Viewing({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.propertyAddress,
    required this.propertyPhotoUrl,
    required this.startsAtUtc,
    required this.status,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    this.hasBuyerContact = true,
  });

  final String id;
  final String propertyId;
  final String propertyTitle;
  final String propertyAddress;
  final String propertyPhotoUrl;

  /// Always UTC; the slot is 30 minutes long.
  final DateTime startsAtUtc;
  final ViewingStatus status;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final bool hasBuyerContact;

  factory Viewing.fromJson(Map<String, dynamic> json) => Viewing(
    id: (json['id'] as int).toString(),
    propertyId: (json['property_id'] as int).toString(),
    propertyTitle: 'Объект №${json['property_id'] as int}',
    propertyAddress: '',
    propertyPhotoUrl: '',
    startsAtUtc: DateTime.parse(json['starts_at'] as String).toUtc(),
    status: ViewingStatus.values.byName(json['status'] as String),
    buyerId: (json['user_id'] as int).toString(),
    buyerName: 'Пользователь №${json['user_id'] as int}',
    buyerPhone: '',
    hasBuyerContact: false,
  );

  @override
  List<Object?> get props => [
    id,
    propertyId,
    startsAtUtc,
    status,
    buyerId,
    buyerName,
    buyerPhone,
  ];
}
