import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/checkpoint.dart';
import '../../theme/app_colors.dart';

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
    this.onCardTap,
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  final Checkpoint checkpoint;
  final bool compact;
  final Color stripColor;
  final String subtitle;
  final void Function(String direction) onDirectionTap;
  final VoidCallback? onCardTap;
  final bool isFavorite;

  /// Async so callers can await [ensureLoggedInForFavorites] before toggling.
  final Future<void> Function()? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final double pad = compact ? 10 : 12;
    final Widget textColumn = Padding(
      padding: EdgeInsets.fromLTRB(pad + 4, pad, 10, pad),
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
              fontSize: compact ? 15 : 16,
            ),
          ),
          if (checkpoint.location.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: compact ? 2 : 4),
            Text(
              checkpoint.location.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMutedLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: compact ? 4 : 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMutedLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    final Widget favoriteButton = IconButton(
      tooltip: 'مفضل',
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: onFavoriteTap == null
          ? null
          : () => unawaited(onFavoriteTap!()),
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? const Color(0xFFE11D48) : AppColors.textMutedLight,
      ),
    );

    final Widget row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Container(width: compact ? 4 : 5, color: stripColor),
          Expanded(
            child: onCardTap == null
                ? textColumn
                : InkWell(
                    onTap: onCardTap,
                    borderRadius: BorderRadius.circular(16),
                    child: textColumn,
                  ),
          ),
          if (onFavoriteTap != null)
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(top: compact ? 2 : 0),
                child: favoriteButton,
              ),
            ),
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
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: AppColors.borderSubtleLight),
    );
    return Material(
      color: ReferenceCheckpointTileTheme.cardBg,
      elevation: 1.5,
      shadowColor: AppColors.brandTeal.withValues(alpha: 0.12),
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
        bg: const Color(0xFFC62828),
        fg: Colors.white,
        icon: Icons.block_rounded,
        text: 'مغلق',
      );
    }
    if (s == CheckpointStatus.crowded) {
      return (
        bg: const Color(0xFFF9A825),
        fg: const Color(0xFF3E2723),
        icon: Icons.traffic_rounded,
        text: 'أزمة',
      );
    }
    if (s == CheckpointStatus.armyPresent) {
      return (
        bg: const Color(0xFFF59E0B),
        fg: const Color(0xFF422006),
        icon: Icons.military_tech_rounded,
        text: 'جيش',
      );
    }
    if (s == CheckpointStatus.settlersPresent) {
      return (
        bg: const Color(0xFFA855F7),
        fg: const Color(0xFF3B0764),
        icon: Icons.home_work_rounded,
        text: 'مستوطنون',
      );
    }
    return (
      bg: const Color(0xFF2E7D32),
      fg: Colors.white,
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 104),
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              decoration: BoxDecoration(
                color: styl.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(styl.icon, color: styl.fg, size: compact ? 16 : 18),
                  const SizedBox(width: 6),
                  Text(
                    styl.text,
                    style: TextStyle(
                      color: styl.fg,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 12.5 : 13.5,
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
