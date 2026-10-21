import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/properties/data/property_repository.dart';
import 'features/viewings/data/viewing_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  Intl.defaultLocale = 'ru';

  const storage = FlutterSecureStorage();
  final client = ApiClient(storage: storage);
  final properties = ApiPropertyRepository(client);

  runApp(
    PropertyVisitApp(
      authRepository: ApiAuthRepository(client),
      propertyRepository: properties,
      viewingRepository: ApiViewingRepository(client, properties),
      apiClient: client,
    ),
  );
}
