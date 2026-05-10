import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/ar_relative_time.dart';
import '../../utils/guest_session.dart';

abstract final class CheckpointCardStyle {
  static const Color navy = Color(0xFF163E6C);
  static const Color arrowBlue = Color(0xFF4A90D9);
  static const double cardHeight = 220;
  /// ارتفاع خلية الشبكة في الإدارة (محتوى البطاقة أقل؛ المحاذاة للأعلى لتقليل الفراغ).
  /// رتل إضافي يمنع overflow عند وجود حاشية المصدر أو اختلاف بسيط في الخط.
  static const double adminCardHeight = 292;
  /// Entrance/exit row: fixed height so we avoid [IntrinsicHeight], which breaks
  /// when descendants use [LayoutBuilder] (Flutter Web intrinsic passes).
  static const double directionStripHeight = 126;
  static const double radius = 16;
}

enum CheckpointCardAppearance {
  light,
  darkUserLike,
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
    this.onCardTap,
    this.appearance = CheckpointCardAppearance.light,
  });

  final Checkpoint checkpoint;
  final void Function(String direction) onStatusBadgeTap;

  /// Replaces the chevron in the top-left (e.g., admin popup menu).
  final Widget? trailing;

  /// Optional row below the badges (e.g., admin action buttons).
  final Widget? footer;

  /// Opens detail screen etc.; does not wrap [footer] so delete/actions stay separate.
  final VoidCallback? onCardTap;

  final CheckpointCardAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = appearance == CheckpointCardAppearance.darkUserLike;
    final Color titleColor =
        dark ? Colors.white : CheckpointCardStyle.navy;
    final Color chevronColor =
        dark ? Colors.white54 : CheckpointCardStyle.arrowBlue;
    final Color dividerColor = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.grey.shade200;
    final Color midDividerColor = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.grey.shade300;

    final Widget mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
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
                    Icon(
                      Icons.chevron_left_rounded,
                      color: chevronColor,
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
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 16, thickness: 1, color: dividerColor),
        SizedBox(
          height: CheckpointCardStyle.directionStripHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Expanded(
                child: _DirectionColumn(
                  appearance: appearance,
                  label: 'الدخول',
                  status: checkpoint.entranceStatus,
                  updatedAt: checkpoint.entranceUpdatedAt,
                  sourceFootnote: Checkpoint.isInAppUpdateSource(
                        checkpoint.entranceSource,
                      )
                      ? '(تحديث من داخل التطبيق)'
                      : null,
                  onTap: () => onStatusBadgeTap('entrance'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: midDividerColor,
                ),
              ),
              Expanded(
                child: _DirectionColumn(
                  appearance: appearance,
                  label: 'الخروج',
                  status: checkpoint.exitStatus,
                  updatedAt: checkpoint.exitUpdatedAt,
                  sourceFootnote: Checkpoint.isInAppUpdateSource(
                        checkpoint.exitSource,
                      )
                      ? '(تحديث من داخل التطبيق)'
                      : null,
                  onTap: () => onStatusBadgeTap('exit'),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Material(
      color: dark ? const Color(0xFF252B38) : Colors.white,
      elevation: dark ? 2 : 3,
      shadowColor: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
      borderRadius: BorderRadius.circular(CheckpointCardStyle.radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (onCardTap != null)
              Expanded(
                child: InkWell(
                  onTap: onCardTap,
                  borderRadius:
                      BorderRadius.circular(CheckpointCardStyle.radius - 2),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: mainColumn,
                  ),
                ),
              )
            else
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: mainColumn,
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
    required this.appearance,
    required this.label,
    required this.status,
    required this.updatedAt,
    required this.onTap,
    this.sourceFootnote,
  });

  final CheckpointCardAppearance appearance;
  final String label;
  final String status;
  final DateTime? updatedAt;
  final VoidCallback onTap;
  final String? sourceFootnote;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = appearance == CheckpointCardAppearance.darkUserLike;
    final Color labelColor =
        dark ? Colors.white.withValues(alpha: 0.88) : CheckpointCardStyle.navy;
    final Color timeColor = dark
        ? Colors.white54
        : CheckpointCardStyle.navy.withValues(alpha: 0.55);
    final Color noteColor = dark
        ? Colors.white38
        : CheckpointCardStyle.navy.withValues(alpha: 0.45);

    // [FittedBox] gives the child unbounded width during layout; [Column] + stretch needs a finite
    // width. [LayoutBuilder] is OK here: direction strip uses fixed height, no [IntrinsicHeight].
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double stripWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 120;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: stripWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusBadge(status: status, onTap: onTap),
                    const SizedBox(height: 4),
                    Text(
                      arabicRelativeSince(updatedAt),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: timeColor,
                        height: 1.15,
                      ),
                    ),
                    if (sourceFootnote != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        sourceFootnote!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 9.5,
                          height: 1.15,
                          color: noteColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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

/// Bottom sheet: all [CheckpointStatus] values.
/// Calls [CheckpointProvider.updateStatus] on tap and pops.
Future<void> showCheckpointStatusSheet({
  required BuildContext context,
  required Checkpoint checkpoint,
  required String direction,
  CheckpointUpdateSource updateSource = CheckpointUpdateSource.user,
}) async {
  if (!await ensureCanMakeCheckpointChanges(context)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  final CheckpointProvider provider = context.read<CheckpointProvider>();
  final String title = direction == 'entrance'
      ? 'تغيير حالة الدخول'
      : 'تغيير حالة الخروج';

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.cardLight,
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
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(bc).height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (
                          int i = 0;
                          i < CheckpointStatus.all.length;
                          i++
                        ) ...<Widget>[
                          if (i > 0) const SizedBox(height: 10),
                          _SheetButton(
                            label: CheckpointStatus.badgeLabelAr(
                              CheckpointStatus.all[i],
                            ),
                            status: CheckpointStatus.all[i],
                            onTap: () => _applyStatus(
                              bc,
                              context,
                              provider,
                              checkpoint,
                              direction,
                              CheckpointStatus.all[i],
                              updateSource,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
  CheckpointUpdateSource updateSource,
) async {
  Navigator.of(sheetContext).pop();
  try {
    await provider.updateStatus(
      checkpoint.id,
      direction,
      status,
      source: updateSource,
    );
    if (parentContext.mounted) {
      ScaffoldMessenger.of(
        parentContext,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التحديث')));
    }
  } catch (e) {
    if (parentContext.mounted) {
      ScaffoldMessenger.of(
        parentContext,
      ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
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
