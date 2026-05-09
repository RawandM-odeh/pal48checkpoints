import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../utils/ar_relative_time.dart';

abstract final class _CardUi {
  static const Color navy = Color(0xFF163E6C);
  static const Color arrowBlue = Color(0xFF4A90D9);
}

class CheckpointList extends StatelessWidget {
  const CheckpointList({super.key});

  Future<void> _showStatusBottomSheet({
    required BuildContext context,
    required Checkpoint checkpoint,
    required String direction,
  }) async {
    final CheckpointProvider provider = context.read<CheckpointProvider>();
    final String title = direction == 'entrance'
        ? 'تغيير حالة الدخول'
        : 'تغيير حالة الخروج';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (BuildContext bc) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + MediaQuery.paddingOf(bc).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(bc).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _CardUi.navy,
                        ),
                  ),
                  const SizedBox(height: 18),
                  _statusSheetButton(
                    context: bc,
                    label: '✓ سالك',
                    bg: CheckpointStatus.badgeColors(CheckpointStatus.open).bg,
                    fg: CheckpointStatus.badgeColors(CheckpointStatus.open).fg,
                    onTap: () async {
                      Navigator.of(bc).pop();
                      await _applyStatus(
                        context: context,
                        provider: provider,
                        checkpoint: checkpoint,
                        direction: direction,
                        status: CheckpointStatus.open,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _statusSheetButton(
                    context: bc,
                    label: '✗ مغلق',
                    bg:
                        CheckpointStatus.badgeColors(CheckpointStatus.closed).bg,
                    fg:
                        CheckpointStatus.badgeColors(CheckpointStatus.closed).fg,
                    onTap: () async {
                      Navigator.of(bc).pop();
                      await _applyStatus(
                        context: context,
                        provider: provider,
                        checkpoint: checkpoint,
                        direction: direction,
                        status: CheckpointStatus.closed,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _statusSheetButton(
                    context: bc,
                    label: '~ مزدحم',
                    bg: CheckpointStatus.badgeColors(CheckpointStatus.crowded)
                        .bg,
                    fg: CheckpointStatus.badgeColors(CheckpointStatus.crowded)
                        .fg,
                    onTap: () async {
                      Navigator.of(bc).pop();
                      await _applyStatus(
                        context: context,
                        provider: provider,
                        checkpoint: checkpoint,
                        direction: direction,
                        status: CheckpointStatus.crowded,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusSheetButton({
    required BuildContext context,
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }

  Future<void> _applyStatus({
    required BuildContext context,
    required CheckpointProvider provider,
    required Checkpoint checkpoint,
    required String direction,
    required String status,
  }) async {
    try {
      await provider.updateStatus(checkpoint.id, direction, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التحديث')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    }
  }

  static Widget _statusBadge({
    required BuildContext context,
    required String status,
    required VoidCallback onTap,
  }) {
    final ({Color bg, Color fg}) styl = CheckpointStatus.badgeColors(status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: styl.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            CheckpointStatus.badgeLabelAr(status),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: styl.fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }

  static Widget _checkpointCard(
    BuildContext context,
    Checkpoint c,
    void Function(String direction) onBadgeTap,
  ) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: _CardUi.arrowBlue,
                      size: 26,
                    ),
                  ),
                  Text(
                    c.name.isEmpty ? 'بدون اسم' : c.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _CardUi.navy,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 18, thickness: 1, color: Colors.grey.shade200),
            Expanded(
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.rtl,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'الدخول',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _CardUi.navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _statusBadge(
                                context: context,
                                status: c.entranceStatus,
                                onTap: () => onBadgeTap('entrance'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            arabicRelativeSince(c.entranceUpdatedAt),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _CardUi.navy.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Colors.grey.shade300,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'الخروج',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _CardUi.navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _statusBadge(
                                context: context,
                                status: c.exitStatus,
                                onTap: () => onBadgeTap('exit'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            arabicRelativeSince(c.exitUpdatedAt),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _CardUi.navy.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
            color: _CardUi.navy.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 220,
        ),
        itemCount: provider.items.length,
        itemBuilder: (BuildContext context, int index) {
          final Checkpoint c = provider.items[index];
          return _checkpointCard(context, c, (String direction) {
            _showStatusBottomSheet(
              context: context,
              checkpoint: c,
              direction: direction,
            );
          });
        },
      ),
    );
  }
}
