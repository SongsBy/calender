import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/models.dart';
import '../../providers/items_provider.dart';
import '../../shared/widgets.dart';
import 'item_dialogs.dart';

class ItemsPage extends ConsumerWidget {
  const ItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Items',
          subtitle: 'Create and manage your items',
          action: FilledButton.icon(
            onPressed: () => ItemFormDialog.show(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Item'),
          ),
        ),
        const SizedBox(height: 24),
        switch (items) {
          AsyncData(:final value) when value.isEmpty => const EmptyState(
              icon: Icons.search,
              title: "You don't have any items yet",
              subtitle: 'Add a new item to get started',
            ),
          AsyncData(:final value) => _ItemsTable(items: value),
          AsyncError(:final error) => _ErrorBox(
              message: extractErrorMessage(error),
              onRetry: () => ref.invalidate(itemsProvider),
            ),
          _ => const PendingTable(columns: 4),
        },
      ],
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.items});

  final List<ItemPublic> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width - 64,
            ),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Description')),
                DataColumn(label: SizedBox.shrink()),
              ],
              rows: [
                for (final item in items)
                  DataRow(
                    cells: [
                      DataCell(_CopyId(id: item.id)),
                      DataCell(
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            item.description?.isNotEmpty == true
                                ? item.description!
                                : 'No description',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: muted,
                              fontStyle: item.description?.isNotEmpty == true
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: _ItemActionsMenu(item: item),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyId extends StatefulWidget {
  const _CopyId({required this.id});

  final String id;

  @override
  State<_CopyId> createState() => _CopyIdState();
}

class _CopyIdState extends State<_CopyId> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.id));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.id,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: muted,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Copy ID',
          iconSize: 14,
          visualDensity: VisualDensity.compact,
          onPressed: _copy,
          icon: Icon(
            _copied ? Icons.check : Icons.copy_outlined,
            color: _copied ? Colors.green : muted,
          ),
        ),
      ],
    );
  }
}

enum _ItemAction { edit, delete }

class _ItemActionsMenu extends StatelessWidget {
  const _ItemActionsMenu({required this.item});

  final ItemPublic item;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<_ItemAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) {
        switch (action) {
          case _ItemAction.edit:
            ItemFormDialog.show(context, item: item);
          case _ItemAction.delete:
            DeleteItemDialog.show(context, item.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _ItemAction.edit,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined, size: 18),
            title: Text('Edit Item'),
          ),
        ),
        PopupMenuItem(
          value: _ItemAction.delete,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline, size: 18, color: error),
            title: Text('Delete Item', style: TextStyle(color: error)),
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
