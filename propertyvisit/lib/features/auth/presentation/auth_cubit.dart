import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import '../domain/user.dart';
import '../../../core/network/api_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.submitting = false,
    this.error,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unauthenticated({String? error})
    : this(status: AuthStatus.unauthenticated, error: error);

  final AuthStatus status;
  final User? user;
  final bool submitting;
  final String? error;

  AuthState copyWith({bool? submitting, String? error}) => AuthState(
    status: status,
    user: user,
    submitting: submitting ?? this.submitting,
    error: error,
  );

  @override
  List<Object?> get props => [status, user, submitting, error];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthState.unknown()) {
    _expired = _repo.sessionExpired.listen((_) {
      if (!_loggingOut) _operation++;
      if (!isClosed) {
        emit(
          const AuthState.unauthenticated(
            error: 'Сессия завершена. Войдите снова.',
          ),
        );
      }
    });
  }

  late final StreamSubscription<void> _expired;
  int _operation = 0;
  bool _loggingOut = false;

  @override
  Future<void> close() async {
    await _expired.cancel();
    await super.close();
  }

  final AuthRepository _repo;

  Future<void> restore() async {
    final operation = ++_operation;
    try {
      final user = await _repo.restore();
      if (isClosed || operation != _operation) return;
      emit(
        user == null
            ? const AuthState.unauthenticated()
            : AuthState(status: AuthStatus.authenticated, user: user),
      );
    } catch (e) {
      if (isClosed || operation != _operation) return;
      if (!isClosed) emit(AuthState.unauthenticated(error: apiErrorMessage(e)));
    }
  }

  Future<void> login(String email, String password) async {
    if (state.submitting) return;
    final operation = ++_operation;
    _loggingOut = false;
    emit(state.copyWith(submitting: true, error: null));
    try {
      final user = await _repo.login(email, password);
      if (isClosed || operation != _operation) return;
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on AuthException catch (e) {
      if (isClosed || operation != _operation) return;
      emit(AuthState.unauthenticated(error: e.message));
    } catch (_) {
      if (isClosed || operation != _operation) return;
      emit(const AuthState.unauthenticated(error: 'Что-то пошло не так'));
    }
  }

  void clearError() {
    if (!isClosed && !state.submitting) emit(state.copyWith());
  }

  Future<bool> register(String email, String password) async {
    if (isClosed || state.submitting) return false;
    final operation = ++_operation;
    emit(state.copyWith(submitting: true));
    try {
      await _repo.register(email, password);
      if (isClosed || operation != _operation) return false;
      emit(const AuthState.unauthenticated());
      return true;
    } on AuthException catch (e) {
      if (!isClosed && operation == _operation) {
        emit(AuthState.unauthenticated(error: e.message));
      }
    } catch (e) {
      if (!isClosed && operation == _operation) {
        emit(AuthState.unauthenticated(error: apiErrorMessage(e)));
      }
    }
    return false;
  }

  Future<void> logout() async {
    final operation = ++_operation;
    _loggingOut = true;
    try {
      await _repo.logout();
      if (isClosed || operation != _operation) return;
      if (!isClosed) emit(const AuthState.unauthenticated());
    } catch (_) {
      if (isClosed || operation != _operation) return;
      if (!isClosed) {
        emit(
          const AuthState.unauthenticated(
            error:
                'Вы вышли на устройстве, но сервер не подтвердил отзыв сессии.',
          ),
        );
      }
    } finally {
      if (operation == _operation) _loggingOut = false;
    }
  }
}
