import 'package:equatable/equatable.dart';

enum UserRole { buyer, admin }

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  @override
  List<Object?> get props => [id, name, email, phone, role];
}
