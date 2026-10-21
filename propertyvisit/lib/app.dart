import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/properties/data/property_repository.dart';
import 'features/viewings/data/viewing_repository.dart';

class PropertyVisitApp extends StatefulWidget {
  const PropertyVisitApp({
    super.key,
    required this.authRepository,
    required this.propertyRepository,
    required this.viewingRepository,
    required this.apiClient,
  });

  final AuthRepository authRepository;
  final PropertyRepository propertyRepository;
  final ViewingRepository viewingRepository;
  final ApiClient apiClient;

  @override
  State<PropertyVisitApp> createState() => _PropertyVisitAppState();
}

class _PropertyVisitAppState extends State<PropertyVisitApp> {
  late final AuthCubit _authCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit(widget.authRepository)..restore();
    _router = createRouter(_authCubit);
  }

  @override
  void dispose() {
    _router.dispose();
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.authRepository),
        RepositoryProvider.value(value: widget.propertyRepository),
        RepositoryProvider.value(value: widget.viewingRepository),
        RepositoryProvider.value(value: widget.apiClient),
      ],
      child: BlocProvider.value(
        value: _authCubit,
        child: MaterialApp.router(
          title: 'PropertyVisit',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        ),
      ),
    );
  }
}
