import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'app_providers.dart';

/// Items list for the current user. Mutations refetch it automatically;
/// call `ref.invalidate(itemsProvider)` to refetch manually.
class ItemsNotifier extends AsyncNotifier<List<ItemPublic>> {
  @override
  Future<List<ItemPublic>> build() async {
    final result =
        await ref.watch(itemsServiceProvider).readItems(skip: 0, limit: 100);
    return result.data;
  }

  Future<void> create(ItemCreate data) async {
    await ref.read(itemsServiceProvider).createItem(data);
    ref.invalidateSelf();
  }

  Future<void> edit(String id, ItemUpdate data) async {
    await ref.read(itemsServiceProvider).updateItem(id, data);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(itemsServiceProvider).deleteItem(id);
    ref.invalidateSelf();
  }
}

final itemsProvider =
    AsyncNotifierProvider<ItemsNotifier, List<ItemPublic>>(ItemsNotifier.new);
