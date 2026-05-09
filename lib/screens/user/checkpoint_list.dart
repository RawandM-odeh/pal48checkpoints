import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';

class CheckpointList extends StatelessWidget {
  const CheckpointList({super.key});

  Future<void> _showStatusPicker(
    BuildContext context,
    Checkpoint checkpoint,
  ) async {
    final CheckpointProvider checkpointProvider =
        context.read<CheckpointProvider>();
    String selected = CheckpointStatus.normalize(checkpoint.status);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setInner) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    checkpoint.name.isEmpty ? 'النقطة' : checkpoint.name,
                    style: Theme.of(bc).textTheme.titleLarge,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'اختر الحالة',
                      style: Theme.of(bc).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...CheckpointStatus.all.map((String status) {
                    final String normalized =
                        CheckpointStatus.normalize(status);
                    return RadioListTile<String>(
                      value: normalized,
                      groupValue: selected,
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setInner(() => selected = value);
                      },
                      title: Align(
                        alignment: Alignment.centerRight,
                        child: Text(CheckpointStatus.labelAr(normalized)),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await checkpointProvider.repository.updateStatus(
                          checkpointId: checkpoint.id,
                          status: selected,
                        );
                        if (bc.mounted) {
                          Navigator.of(bc).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حفظ الحالة'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (bc.mounted) {
                          ScaffoldMessenger.of(bc).showSnackBar(
                            SnackBar(
                              content: Text('خطأ في الحفظ: $e'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckpointProvider provider = context.watch<CheckpointProvider>();

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
          'لا توجد نقاط بعد',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemBuilder: (BuildContext context, int index) {
        final Checkpoint c = provider.items[index];
        final Color color = CheckpointStatus.chipColor(context, c.status);
        return Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => _showStatusPicker(context, c),
            trailing: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.22),
              child: Icon(
                Icons.circle,
                color: color,
                size: 16,
              ),
            ),
            title: Align(
              alignment: Alignment.centerRight,
              child: Text(
                c.name.isEmpty ? 'بدون اسم' : c.name,
                style: theme.textTheme.titleMedium,
              ),
            ),
            subtitle: Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (c.location.isNotEmpty) Text(c.location),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        CheckpointStatus.labelAr(c.status),
                        style: theme.textTheme.labelLarge?.copyWith(color: color),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      separatorBuilder: (BuildContext context, int _) =>
          const SizedBox(height: 8),
      itemCount: provider.items.length,
    );
  }
}
