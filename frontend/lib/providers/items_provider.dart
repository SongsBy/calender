import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'app_providers.dart';

/// Current search text for the items list. Changing it refetches the list.
class ItemsSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final itemsSearchProvider = NotifierProvider<ItemsSearchNotifier, String>(
  ItemsSearchNotifier.new,
);

/// Items list for the current user, filtered by [itemsSearchProvider].
/// Mutations refetch it automatically; call `ref.invalidate(itemsProvider)`
/// to refetch manually.
class ItemsNotifier extends AsyncNotifier<List<ItemPublic>> {
  @override
  Future<List<ItemPublic>> build() async {
    final q = ref.watch(itemsSearchProvider);
    final result = await ref
        .watch(itemsServiceProvider)
        .readItems(skip: 0, limit: 100, q: q);
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

final itemsProvider = AsyncNotifierProvider<ItemsNotifier, List<ItemPublic>>(
  ItemsNotifier.new,
);
