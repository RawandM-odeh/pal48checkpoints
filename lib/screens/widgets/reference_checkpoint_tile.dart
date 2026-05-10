import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/checkpoint.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/city_display_ar.dart';

/// بطاقة فاتحة ناعمة (قائمة المستخدم + بطاقة المرجع).
abstract final class ReferenceCheckpointTileTheme {
  static const Color cardBg = AppColors.cardLight;
  static const Color primaryBlue = AppColors.brandTeal;
}

/// شريط جانبي ملوّن حسب أسوأ حالة (دخول/خروج).
Color checkpointStripColor(Checkpoint c) {
  final String e = CheckpointStatus.normalize(c.entranceStatus);
  final String x = CheckpointStatus.normalize(c.exitStatus);
  if (e == CheckpointStatus.closed || x == CheckpointStatus.closed) {
    return const Color(0xFFE53935);
  }
  if (e == CheckpointStatus.armyPresent || x == CheckpointStatus.armyPresent) {
    return const Color(0xFFF59E0B);
  }
  if (e == CheckpointStatus.settlersPresent ||
      x == CheckpointStatus.settlersPresent) {
    return const Color(0xFF9333EA);
  }
  if (e == CheckpointStatus.crowded || x == CheckpointStatus.crowded) {
    return const Color(0xFFFFA726);
  }
  return const Color(0xFF43A047);
}

/// بطاقة حاجز بنمط الواجهة الرئيسية (عنوان، مدينة، وقت، شارات دخول/خروج).
class ReferenceCheckpointTile extends StatelessWidget {
  const ReferenceCheckpointTile({
    super.key,
    required this.checkpoint,
    required this.compact,
    required this.stripColor,
    required this.subtitle,
    required this.onDirectionTap,
    this.subtitleMaxLines = 6,
    this.onCardTap,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.isSaved = false,
    this.onSavedTap,
  });

  final Checkpoint checkpoint;
  final bool compact;
  final Color stripColor;
  final String subtitle;
  final int subtitleMaxLines;
  final void Function(String direction) onDirectionTap;
  final VoidCallback? onCardTap;
  final bool isFavorite;

  /// Async so callers can await [ensureLoggedInForFavorites] before toggling.
  final Future<void> Function()? onFavoriteTap;

  /// «المثبتة» — متميز عن المفضلة.
  final bool isSaved;

  /// Async لتشغيل كاشف تسجيل الدخول قبل التبديل.
  final Future<void> Function()? onSavedTap;

  @override
  Widget build(BuildContext context) {
    final double pad = compact ? 12 : 14;
    final Widget textColumn = Padding(
      padding: EdgeInsets.fromLTRB(pad + 6, pad, 12, pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            checkpoint.name.isEmpty ? 'بدون اسم' : checkpoint.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 15.5 : 16.5,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
          if (checkpoint.location.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: compact ? 2 : 4),
            Text(
              cityDisplayNameAr(checkpoint.location),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMutedLight,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
          SizedBox(height: compact ? 4 : 6),
          Text(
            subtitle,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMutedLight,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );

    final Widget? savedButton = onSavedTap == null
        ? null
        : IconButton(
            tooltip: 'مثبَّتة',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => unawaited(onSavedTap!()),
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
              color: isSaved
                  ? ReferenceCheckpointTileTheme.primaryBlue
                  : AppColors.textMutedLight,
              size: 24,
            ),
          );

    final Widget? favoriteButton = onFavoriteTap == null
        ? null
        : IconButton(
            tooltip: 'مفضل',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => unawaited(onFavoriteTap!()),
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color:
                  isFavorite ? const Color(0xFFE11D48) : AppColors.textMutedLight,
            ),
          );

    final Widget? bookmarksColumn =
        savedButton != null || favoriteButton != null
        ? Padding(
            padding: EdgeInsets.only(top: compact ? 2 : 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ?savedButton,
                ?favoriteButton,
              ],
            ),
          )
        : null;

    final Widget row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Container(width: compact ? 5 : 6, color: stripColor),
          Expanded(
            child: onCardTap == null
                ? textColumn
                : InkWell(
                    onTap: onCardTap,
                    borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                    child: textColumn,
                  ),
          ),
          if (bookmarksColumn != null)
            Align(alignment: Alignment.center, child: bookmarksColumn),
          Padding(
            padding: EdgeInsets.fromLTRB(4, pad, pad, pad),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _InboundOutboundBadge(
                  label: 'للداخل',
                  status: checkpoint.entranceStatus,
                  compact: compact,
                  onTap: () => onDirectionTap('entrance'),
                ),
                SizedBox(height: compact ? 6 : 8),
                _InboundOutboundBadge(
                  label: 'للخارج',
                  status: checkpoint.exitStatus,
                  compact: compact,
                  onTap: () => onDirectionTap('exit'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final RoundedRectangleBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppLayout.radiusLg),
      side: const BorderSide(color: AppColors.borderSubtleLight, width: 1),
    );
    return Material(
      color: ReferenceCheckpointTileTheme.cardBg,
      elevation: AppLayout.cardElevation,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: row,
    );
  }
}

class _InboundOutboundBadge extends StatelessWidget {
  const _InboundOutboundBadge({
    required this.label,
    required this.status,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final String status;
  final bool compact;
  final VoidCallback onTap;

  static ({Color bg, Color fg, IconData icon, String text}) _style(String raw) {
    final String s = CheckpointStatus.normalize(raw);
    if (s == CheckpointStatus.closed) {
      return (
        bg: const Color(0xFFFEE4E6),
        fg: const Color(0xFFB91C1C),
        icon: Icons.block_rounded,
        text: 'مغلق',
      );
    }
    if (s == CheckpointStatus.crowded) {
      return (
        bg: const Color(0xFFFEF9C3),
        fg: const Color(0xFFC2410C),
        icon: Icons.traffic_rounded,
        text: 'أزمة',
      );
    }
    if (s == CheckpointStatus.armyPresent) {
      return (
        bg: const Color(0xFFFEF3C7),
        fg: const Color(0xFFB45309),
        icon: Icons.military_tech_rounded,
        text: 'جيش',
      );
    }
    if (s == CheckpointStatus.settlersPresent) {
      return (
        bg: const Color(0xFFF3E8FF),
        fg: const Color(0xFF7E22CE),
        icon: Icons.home_work_rounded,
        text: 'مستوطنون',
      );
    }
    return (
      bg: const Color(0xFFD1FAE5),
      fg: const Color(0xFF047857),
      icon: Icons.check_rounded,
      text: 'سالك',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg, IconData icon, String text}) styl = _style(
      status,
    );
    final double hPad = compact ? 8 : 10;
    final double vPad = compact ? 6 : 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textMutedLight,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppLayout.radiusSm + 2),
            child: Container(
              constraints: const BoxConstraints(minWidth: 108),
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              decoration: BoxDecoration(
                color: styl.bg,
                borderRadius: BorderRadius.circular(AppLayout.radiusSm + 2),
                border: Border.all(color: styl.fg.withValues(alpha: 0.14)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: styl.fg.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(styl.icon, color: styl.fg, size: compact ? 15.5 : 17),
                  const SizedBox(width: 6),
                  Text(
                    styl.text,
                    style: TextStyle(
                      color: styl.fg,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 12.5 : 13.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
