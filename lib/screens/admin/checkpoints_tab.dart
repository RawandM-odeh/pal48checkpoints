import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';

class CheckpointsTab extends StatelessWidget {
  const CheckpointsTab({super.key});

  Future<void> _showAddDialog(BuildContext context) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController locationCtrl = TextEditingController();
    String status = CheckpointStatus.open;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, void Function(void Function()) setInner) {
            return AlertDialog(
              title: const Text('إضافة نقطة'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: nameCtrl,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(labelText: 'الاسم'),
                        validator: (String? v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'الاسم مطلوب';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: locationCtrl,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(labelText: 'الموقع'),
                        validator: (String? v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'الموقع مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(labelText: 'الحالة'),
                        items: CheckpointStatus.all
                            .map(
                              (String s) => DropdownMenuItem<String>(
                                value: s,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(CheckpointStatus.labelAr(s)),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          if (v == null) {
                            return;
                          }
                          setInner(() => status = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
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
                        location: locationCtrl.text,
                        status: status,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تمت الإضافة')),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('خطأ: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editStatus(
    BuildContext context,
    Checkpoint checkpoint,
  ) async {
    final CheckpointProvider provider = context.read<CheckpointProvider>();
    String selected = CheckpointStatus.normalize(checkpoint.status);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, void Function(void Function()) setInner) {
            return AlertDialog(
              title: Text(
                checkpoint.name.isEmpty ? 'تعديل الحالة' : checkpoint.name,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: CheckpointStatus.all.map((String s) {
                  final String n = CheckpointStatus.normalize(s);
                  return RadioListTile<String>(
                    value: n,
                    groupValue: selected,
                    onChanged: (String? v) {
                      if (v == null) {
                        return;
                      }
                      setInner(() => selected = v);
                    },
                    title: Align(
                      alignment: Alignment.centerRight,
                      child: Text(CheckpointStatus.labelAr(n)),
                    ),
                  );
                }).toList(),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await provider.repository.updateStatus(
                        checkpointId: checkpoint.id,
                        status: selected,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم التحديث')),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('خطأ: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Checkpoint c) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('حذف النقطة؟'),
          content: Text(
            c.name.isEmpty ? 'سيتم حذف هذه النقطة نهائياً.' : c.name,
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
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      await context.read<CheckpointProvider>().repository
          .deleteCheckpoint(c.id);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('نقطة جديدة'),
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
            return const Center(child: Text('لا توجد نقاط'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: provider.items.length,
            separatorBuilder: (BuildContext context, int _) =>
                const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final Checkpoint c = provider.items[index];
              final Color color = CheckpointStatus.chipColor(context, c.status);
              return Card(
                child: ListTile(
                  title: Align(
                    alignment: Alignment.centerRight,
                    child: Text(c.name.isEmpty ? 'بدون اسم' : c.name),
                  ),
                  subtitle: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        if (c.location.isNotEmpty) Text(c.location),
                        Text(
                          CheckpointStatus.labelAr(c.status),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        _editStatus(context, c);
                      } else if (value == 'delete') {
                        _confirmDelete(context, c);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('تعديل الحالة'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('حذف'),
                        ),
                      ];
                    },
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
