import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/storage.dart';
import '../services/items_service.dart';
import '../services/login_service.dart';
import '../services/users_service.dart';
import 'auth_provider.dart';

/// Overridden in `main.dart` once SharedPreferences is ready.
final storageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('storageProvider must be overridden');
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(storageProvider);
  return createApiClient(storage, () {
    // Runs at request time, never during a provider build, so this does not
    // create a circular dependency with authProvider.
    ref.read(authProvider.notifier).expireSession();
  });
});

final loginServiceProvider = Provider<LoginService>(
  (ref) => LoginService(ref.watch(dioProvider)),
);

final usersServiceProvider = Provider<UsersService>(
  (ref) => UsersService(ref.watch(dioProvider)),
);

final itemsServiceProvider = Provider<ItemsService>(
  (ref) => ItemsService(ref.watch(dioProvider)),
);
