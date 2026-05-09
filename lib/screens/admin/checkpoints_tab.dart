import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../widgets/checkpoint_card.dart';

class CheckpointsTab extends StatelessWidget {
  const CheckpointsTab({super.key});

  Future<void> _onBadgeTap(
    BuildContext context,
    Checkpoint checkpoint,
    String direction,
  ) async {
    await showCheckpointStatusSheet(
      context: context,
      checkpoint: checkpoint,
      direction: direction,
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة حاجز'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: nameCtrl,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'اسم الحاجز',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'الاسم مطلوب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حالة الدخول والخروج تبدأ كـ «سالك» افتراضياً.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  try {
                    await context.read<CheckpointProvider>().repository
                        .addCheckpoint(
                      name: nameCtrl.text,
                      location: '',
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تمت الإضافة')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ: $e')),
                      );
                    }
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );

    nameCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, Checkpoint c) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف الحاجز؟'),
            content: Text(
              c.name.isEmpty ? 'سيتم حذف هذا الحاجز نهائياً.' : c.name,
              textAlign: TextAlign.right,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      await context.read<CheckpointProvider>().repository.deleteCheckpoint(c.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحذف')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckpointProvider provider = context.watch<CheckpointProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        tooltip: 'إضافة حاجز',
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (provider.loading && provider.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            );
          }
          if (provider.items.isEmpty) {
            return Center(
              child: Text(
                'لا توجد حواجز',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: CheckpointCardStyle.navy.withValues(alpha: 0.6),
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: CheckpointCardStyle.adminCardHeight,
            ),
            itemCount: provider.items.length,
            itemBuilder: (BuildContext context, int index) {
              final Checkpoint c = provider.items[index];
              return CheckpointCard(
                checkpoint: c,
                onStatusBadgeTap: (String direction) =>
                    _onBadgeTap(context, c, direction),
                trailing: const SizedBox(width: 26),
                footer: TextButton.icon(
                  onPressed: () => _confirmDelete(context, c),
                  icon: const Text('🗑️', style: TextStyle(fontSize: 18)),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
