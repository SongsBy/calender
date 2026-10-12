import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'app_providers.dart';

/// Admin users list. Mutations refetch it automatically.
class UsersNotifier extends AsyncNotifier<List<UserPublic>> {
  @override
  Future<List<UserPublic>> build() async {
    final result =
        await ref.watch(usersServiceProvider).readUsers(skip: 0, limit: 100);
    return result.data;
  }

  Future<void> create(UserCreate data) async {
    await ref.read(usersServiceProvider).createUser(data);
    ref.invalidateSelf();
  }

  Future<void> edit(String id, UserUpdate data) async {
    await ref.read(usersServiceProvider).updateUser(id, data);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(usersServiceProvider).deleteUser(id);
    ref.invalidateSelf();
  }
}

final usersProvider =
    AsyncNotifierProvider<UsersNotifier, List<UserPublic>>(UsersNotifier.new);
