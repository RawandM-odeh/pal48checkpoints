import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../utils/ar_relative_time.dart';

abstract final class CheckpointCardStyle {
  static const Color navy = Color(0xFF163E6C);
  static const Color arrowBlue = Color(0xFF4A90D9);
  static const double cardHeight = 220;
  static const double adminCardHeight = 248;
  static const double radius = 16;
}

/// White rounded card showing entrance/exit status badges + relative times.
/// Tapping a badge calls [onStatusBadgeTap] with `entrance` or `exit`.
class CheckpointCard extends StatelessWidget {
  const CheckpointCard({
    super.key,
    required this.checkpoint,
    required this.onStatusBadgeTap,
    this.trailing,
    this.footer,
  });

  final Checkpoint checkpoint;
  final void Function(String direction) onStatusBadgeTap;

  /// Replaces the chevron in the top-left (e.g., admin popup menu).
  final Widget? trailing;

  /// Optional row below the badges (e.g., admin action buttons).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(CheckpointCardStyle.radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                    child: trailing ??
                        const Icon(
                          Icons.chevron_left_rounded,
                          color: CheckpointCardStyle.arrowBlue,
                          size: 26,
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      checkpoint.name.isEmpty ? 'بدون اسم' : checkpoint.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CheckpointCardStyle.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 16, thickness: 1, color: Colors.grey.shade200),
            Expanded(
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.rtl,
                  children: <Widget>[
                    Expanded(
                      child: _DirectionColumn(
                        label: 'الدخول',
                        status: checkpoint.entranceStatus,
                        updatedAt: checkpoint.entranceUpdatedAt,
                        onTap: () => onStatusBadgeTap('entrance'),
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
                      child: _DirectionColumn(
                        label: 'الخروج',
                        status: checkpoint.exitStatus,
                        updatedAt: checkpoint.exitUpdatedAt,
                        onTap: () => onStatusBadgeTap('exit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (footer != null) ...<Widget>[
              const SizedBox(height: 8),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectionColumn extends StatelessWidget {
  const _DirectionColumn({
    required this.label,
    required this.status,
    required this.updatedAt,
    required this.onTap,
  });

  final String label;
  final String status;
  final DateTime? updatedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: CheckpointCardStyle.navy,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: _StatusBadge(status: status, onTap: onTap),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          arabicRelativeSince(updatedAt),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: CheckpointCardStyle.navy.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.onTap});

  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
}

/// Bottom sheet with three big buttons (open / closed / crowded).
/// Calls [CheckpointProvider.updateStatus] on tap and pops.
Future<void> showCheckpointStatusSheet({
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
    backgroundColor: Colors.white,
    showDragHandle: true,
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
                        color: CheckpointCardStyle.navy,
                      ),
                ),
                const SizedBox(height: 18),
                _SheetButton(
                  label: '✓ سالك',
                  status: CheckpointStatus.open,
                  onTap: () =>
                      _applyStatus(bc, context, provider, checkpoint, direction,
                          CheckpointStatus.open),
                ),
                const SizedBox(height: 10),
                _SheetButton(
                  label: '✗ مغلق',
                  status: CheckpointStatus.closed,
                  onTap: () =>
                      _applyStatus(bc, context, provider, checkpoint, direction,
                          CheckpointStatus.closed),
                ),
                const SizedBox(height: 10),
                _SheetButton(
                  label: '~ مزدحم',
                  status: CheckpointStatus.crowded,
                  onTap: () =>
                      _applyStatus(bc, context, provider, checkpoint, direction,
                          CheckpointStatus.crowded),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _applyStatus(
  BuildContext sheetContext,
  BuildContext parentContext,
  CheckpointProvider provider,
  Checkpoint checkpoint,
  String direction,
  String status,
) async {
  Navigator.of(sheetContext).pop();
  try {
    await provider.updateStatus(checkpoint.id, direction, status);
    if (parentContext.mounted) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(content: Text('تم حفظ التحديث')),
      );
    }
  } catch (e) {
    if (parentContext.mounted) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text('خطأ في الحفظ: $e')),
      );
    }
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.status,
    required this.onTap,
  });

  final String label;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg}) styl = CheckpointStatus.badgeColors(status);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: styl.bg,
        foregroundColor: styl.fg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}
