import 'package:flutter/material.dart';

import '../../models/checkpoint.dart';

/// ألوان البطاقة الداكنة (قائمة المستخدم + بطاقة المرجع).
abstract final class ReferenceCheckpointTileTheme {
  static const Color cardBg = Color(0xFF2C2F38);
  static const Color primaryBlue = Color(0xFF2196F3);
}

/// شريط جانبي ملوّن حسب أسوأ حالة (دخول/خروج).
Color checkpointStripColor(Checkpoint c) {
  final String e = CheckpointStatus.normalize(c.entranceStatus);
  final String x = CheckpointStatus.normalize(c.exitStatus);
  if (e == CheckpointStatus.closed || x == CheckpointStatus.closed) {
    return const Color(0xFFE53935);
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
  });

  final Checkpoint checkpoint;
  final bool compact;
  final Color stripColor;
  final String subtitle;
  final void Function(String direction) onDirectionTap;
  final VoidCallback? onCardTap;

  @override
  Widget build(BuildContext context) {
    final double pad = compact ? 10 : 12;
    final Widget row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Container(width: compact ? 4 : 5, color: stripColor),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad + 4, pad, 10, pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    checkpoint.name.isEmpty ? 'بدون اسم' : checkpoint.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
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
                            color: Colors.white38,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  SizedBox(height: compact ? 4 : 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, pad, pad, pad),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: ReferenceCheckpointTileTheme.cardBg,
        elevation: 2,
        shadowColor: Colors.black54,
        child: onCardTap == null
            ? row
            : InkWell(
                onTap: onCardTap,
                child: row,
              ),
      ),
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

  static ({Color bg, Color fg, IconData icon, String text}) _style(
    String raw,
  ) {
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
        icon: Icons.groups_rounded,
        text: 'مزدحم',
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
    final ({Color bg, Color fg, IconData icon, String text}) styl =
        _style(status);
    final double hPad = compact ? 8 : 10;
    final double vPad = compact ? 6 : 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white60,
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
              padding: EdgeInsets.symmetric(
                horizontal: hPad,
                vertical: vPad,
              ),
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
