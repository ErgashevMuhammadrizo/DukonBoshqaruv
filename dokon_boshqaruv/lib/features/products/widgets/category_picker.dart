```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../src/app.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';

Future<Category?> showCreateCategory(BuildContext context) {
  return showDialog<Category>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CreateCategoryDialog(),
  );
}

class _CreateCategoryDialog extends ConsumerStatefulWidget {
  const _CreateCategoryDialog();

  @override
  ConsumerState<_CreateCategoryDialog> createState() =>
      _CreateCategoryDialogState();
}

class _CreateCategoryDialogState
    extends ConsumerState<_CreateCategoryDialog> {
  final TextEditingController controller = TextEditingController();

  bool saving = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;

    final name = controller.text.trim();

    if (name.isEmpty) {
      setState(() {
        error = 'Kategoriya nomini kiriting';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final raw = await ref.read(apiProvider).createCategory(name);
      final category = Category.fromJson(raw);

      ref.invalidate(categoriesProvider);

      if (!mounted) return;

      Navigator.pop(context, category);
    } on DioException catch (e) {
      if (!mounted) return;

      final data = e.response?.data;

      setState(() {
        error = data is Map && data['name'] != null
            ? data['name'].toString()
            : 'Kategoriya saqlanmadi. Internetni tekshiring va qayta urinib ko‘ring.';

        saving = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error = 'Kategoriya saqlanmadi. Qayta urinib ko‘ring.';
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: const Text('Yangi kategoriya'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            autofocus: true,
            enabled: !saving,
            maxLength: 160,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => save(),
            decoration: InputDecoration(
              labelText: 'Kategoriya nomi',
              hintText: 'Masalan: Kiyimlar, Elektronika',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(saving ? 'Saqlanmoqda…' : 'Qo‘shish'),
          ),
        ],
      ),
    );
  }
}

class CategoryPicker extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const CategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        categoriesAsync.when(
          data: (categories) {
            final selected = categories.any((c) => c.id == value)
                ? value
                : null;

            return DropdownButtonFormField<int>(
              key: ValueKey(selected),
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kategoriya',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Kategoriyasiz'),
                ),
                ...categories.map(
                  (category) => DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => TextButton.icon(
            onPressed: () => ref.invalidate(categoriesProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Kategoriyalarni qayta yuklash'),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Yangi kategoriya'),
            onPressed: () async {
              final category = await showCreateCategory(context);

              if (context.mounted && category != null) {
                onChanged(category.id);
              }
            },
          ),
        ),
      ],
    );
  }
}

class CategoryToolbar extends ConsumerWidget {
  const CategoryToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(productFiltersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Kategoriyalar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Yangi kategoriya'),
                onPressed: () async {
                  final created = await showCreateCategory(context);

                  if (context.mounted && created != null) {
                    ref.read(productFiltersProvider.notifier).state = ref
                        .read(productFiltersProvider)
                        .copyWith(categoryId: created.id);
                  }
                },
              ),
            ],
          ),
          categoriesAsync.when(
            data: (categories) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Barchasi'),
                      selected: filters.categoryId == null,
                      onSelected: (_) {
                        ref.read(productFiltersProvider.notifier).state =
                            filters.copyWith(categoryId: null);
                      },
                    ),
                    ...categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(category.name),
                          selected: filters.categoryId == category.id,
                          onSelected: (_) {
                            ref.read(productFiltersProvider.notifier).state =
                                filters.copyWith(
                              categoryId: category.id,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => TextButton.icon(
              onPressed: () => ref.invalidate(categoriesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Kategoriyalar yuklanmadi. Qayta urinish',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```