import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/properties/presentation/screens/admin_properties_screen.dart';
import '../../features/properties/presentation/screens/catalog_screen.dart';
import '../../features/properties/presentation/screens/property_details_screen.dart';
import '../../features/viewings/presentation/screens/admin_bookings_screen.dart';
import '../../features/viewings/presentation/screens/booking_screen.dart';
import '../../features/viewings/presentation/screens/my_viewings_screen.dart';
import 'home_shell.dart';

/// Cubit не реализует Listenable — адаптируем его поток для go_router.
class _CubitRefreshListenable extends ChangeNotifier {
  _CubitRefreshListenable(AuthCubit cubit) {
    _sub = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<void> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _CubitRefreshListenable(authCubit),
    redirect: (context, state) {
      final status = authCubit.state.status;
      final location = state.matchedLocation;
      final isAdmin = authCubit.state.user?.role == UserRole.admin;

      if (status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }
      if (status == AuthStatus.unauthenticated) {
        return location == '/login' ? null : '/login';
      }
      if (location == '/splash' || location == '/login') {
        return isAdmin ? '/admin/properties' : '/catalog';
      }
      // Разделение зон по роли.
      if (isAdmin && !location.startsWith('/admin')) return '/admin/properties';
      if (!isAdmin && location.startsWith('/admin')) return '/catalog';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      // Зона покупателя.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/catalog',
                builder: (_, _) => const CatalogScreen(),
                routes: [
                  GoRoute(
                    path: 'property/:id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => PropertyDetailsScreen(
                      propertyId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'book',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, state) => BookingScreen(
                          propertyId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-viewings',
                builder: (_, state) =>
                    MyViewingsScreen(key: ValueKey(state.extra)),
              ),
            ],
          ),
        ],
      ),
      // Зона администратора.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/properties',
                builder: (_, _) => const AdminPropertiesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/bookings',
                builder: (_, _) => const AdminBookingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
