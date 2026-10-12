import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/toast.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/items_provider.dart';
import '../../shared/widgets.dart';

/// Add / Edit item dialog. Pass `item` to edit, omit it to create.
class ItemFormDialog extends ConsumerStatefulWidget {
  const ItemFormDialog({super.key, this.item});

  final ItemPublic? item;

  static Future<void> show(BuildContext context, {ItemPublic? item}) {
    return showDialog(
      context: context,
      builder: (_) => ItemFormDialog(item: item),
    );
  }

  @override
  ConsumerState<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _description =
      TextEditingController(text: widget.item?.description ?? '');
  bool _pending = false;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending || !_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    final title = _title.text.trim();
    final description =
        _description.text.trim().isEmpty ? null : _description.text.trim();
    try {
      final notifier = ref.read(itemsProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          widget.item!.id,
          ItemUpdate(title: title, description: description),
        );
        Toast.success('Item updated successfully');
      } else {
        await notifier.create(
          ItemCreate(title: title, description: description),
        );
        Toast.success('Item created successfully');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Toast.error(extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Item' : 'Add Item'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit
                    ? 'Update the item details below.'
                    : 'Fill in the details to add a new item.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              const FieldLabel('Title', required: true),
              TextFormField(
                controller: _title,
                autofocus: true,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    Validators.required(v, message: 'Title is required'),
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Description'),
              TextFormField(
                controller: _description,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(hintText: 'Description'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _pending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        LoadingButton(
          loading: _pending,
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Delete confirmation dialog for an item.
class DeleteItemDialog extends ConsumerStatefulWidget {
  const DeleteItemDialog({super.key, required this.id});

  final String id;

  static Future<void> show(BuildContext context, String id) {
    return showDialog(
      context: context,
      builder: (_) => DeleteItemDialog(id: id),
    );
  }

  @override
  ConsumerState<DeleteItemDialog> createState() => _DeleteItemDialogState();
}

class _DeleteItemDialogState extends ConsumerState<DeleteItemDialog> {
  bool _pending = false;

  Future<void> _delete() async {
    if (_pending) return;
    setState(() => _pending = true);
    try {
      await ref.read(itemsProvider.notifier).delete(widget.id);
      Toast.success('The item was deleted successfully');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Toast.error(extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Item'),
      content: const SizedBox(
        width: 420,
        child: Text(
          'This item will be permanently deleted. Are you sure? '
          'You will not be able to undo this action.',
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _pending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        LoadingButton(
          loading: _pending,
          destructive: true,
          onPressed: _delete,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
