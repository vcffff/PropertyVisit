import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

import '../domain/user.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Stream<void> get sessionExpired => const Stream.empty();
  bool get isDemo => false;
  Future<User> login(String email, String password);
  Future<void> register(String email, String password) async {
    throw const AuthException('Регистрация недоступна в демо-режиме.');
  }

  Future<void> logout();
  Future<User?> restore();

  /// Access token для Authorization-заголовка ApiClient.
  Future<String?> accessToken();
}

class ApiAuthRepository extends AuthRepository {
  ApiAuthRepository(this.client);
  final ApiClient client;
  @override
  Stream<void> get sessionExpired => client.sessionExpired;

  @override
  Future<void> register(String email, String password) async {
    try {
      // Registration returns a user summary, NOT a token pair.
      await client.authDio.post<Map<String, dynamic>>(
        '/register',
        data: {'email': email.trim(), 'password': password},
      );
    } on DioException catch (e) {
      throw AuthException(
        e.response?.statusCode == 400
            ? 'Не удалось создать аккаунт. Проверьте email и пароль (от 6 символов). Если email уже занят, попробуйте войти.'
            : apiErrorMessage(e),
      );
    }
  }

  @override
  Future<User> login(String email, String password) async {
    try {
      final response = await client.authDio.post<Map<String, dynamic>>(
        '/login',
        data: {'email': email.trim(), 'password': password},
      );
      await client.startSession(response.data!);
      return await _me();
    } on DioException catch (e) {
      throw AuthException(
        e.response?.statusCode == 401
            ? 'Неверный email или пароль'
            : apiErrorMessage(e),
      );
    }
  }

  Future<User> _me() async {
    final response = await client.dio.get<Map<String, dynamic>>('/users/me');
    final json = response.data!;
    final role = json['role'];
    if (role != 'admin' && role != 'user') {
      throw const FormatException('Unknown role');
    }
    return User(
      id: (json['id'] as int).toString(),
      name: json['email'] as String,
      email: json['email'] as String,
      phone: '',
      role: role == 'admin' ? UserRole.admin : UserRole.buyer,
    );
  }

  @override
  Future<User?> restore() async =>
      await client.tokens() == null ? null : await _me();
  @override
  Future<String?> accessToken() async => (await client.tokens())?.access;
  @override
  Future<void> logout() => client.logout();
}

class MockAuthRepository extends AuthRepository {
  MockAuthRepository(this._storage);

  static const _demoPassword = 'demo1234';
  static const _kSession = 'pv_session_role';
  static const _kToken = 'pv_access_token';

  final FlutterSecureStorage _storage;
  @override
  bool get isDemo => true;

  @override
  Future<User> login(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final key = email.trim().toLowerCase();
    final UserRole? role = switch (key) {
      'buyer@demo.kz' => UserRole.buyer,
      'admin@demo.kz' => UserRole.admin,
      _ => null,
    };
    if (role == null || password != _demoPassword) {
      throw const AuthException('Неверный email или пароль');
    }
    final user = _userFor(role);
    await _storage.write(key: _kSession, value: role.name);
    await _storage.write(key: _kToken, value: 'mock-token-${role.name}');
    return user;
  }

  @override
  Future<void> logout() async {
    await _storage.delete(key: _kSession);
    await _storage.delete(key: _kToken);
  }

  @override
  Future<User?> restore() async {
    final roleName = await _storage.read(key: _kSession);
    if (roleName == null) return null;
    try {
      return _userFor(UserRole.values.byName(roleName));
    } on ArgumentError {
      await _storage.delete(key: _kSession);
      return null;
    }
  }

  @override
  Future<String?> accessToken() => _storage.read(key: _kToken);

  User _userFor(UserRole role) => switch (role) {
    UserRole.buyer => const User(
      id: 'u-buyer',
      name: 'Айдар Сериков',
      email: 'buyer@demo.kz',
      phone: '+7 701 123 45 67',
      role: UserRole.buyer,
    ),
    UserRole.admin => const User(
      id: 'u-admin',
      name: 'Менеджер PropertyVisit',
      email: 'admin@demo.kz',
      phone: '+7 701 000 00 01',
      role: UserRole.admin,
    ),
  };
}
