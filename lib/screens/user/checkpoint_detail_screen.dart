import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../theme/app_colors.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/user_location_provider.dart';
import '../../utils/ar_relative_time.dart';
import '../../utils/city_display_ar.dart';
import '../../utils/guest_session.dart';
import '../widgets/checkpoint_card.dart';

/// واجهة فاتحة ناعمة متناغمة مع ثيم التطبيق.
const Color _pageBg = AppColors.shellBackground;
const Color _surfaceCard = AppColors.cardLight;
const Color _surfaceElevated = AppColors.surfaceSoft;
const Color _accentBlue = AppColors.brandTeal;
const Color _successGreen = Color(0xFF16A34A);
const Color _headerBarBg = AppColors.surfaceSoft;
const double _kUpdateRadiusKm = 1.5;

/// شاشة تفاصيل حاجز — تبويبات: آخر التحديثات، أرسل تحديث، معلومات الحاجز.
class CheckpointDetailScreen extends StatefulWidget {
  const CheckpointDetailScreen({
    super.key,
    required this.initialCheckpoint,
    this.bypassProximityCheck = false,
    this.initialTabIndex = 0,
  });

  final Checkpoint initialCheckpoint;

  /// لوحة الإدارة: إرسال تحديث دون شرط القرب من الحاجز.
  final bool bypassProximityCheck;

  /// 0 آخر التحديثات، 1 أرسل تحديث، 2 معلومات الحاجز.
  final int initialTabIndex;

  @override
  State<CheckpointDetailScreen> createState() => _CheckpointDetailScreenState();
}

class _CheckpointDetailScreenState extends State<CheckpointDetailScreen> {
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 2);
    _scheduleLocationResolveIfNeeded();
  }

  void _scheduleLocationResolveIfNeeded() {
    if (_tabIndex == 1 && !widget.bypassProximityCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<UserLocationProvider>().resolve();
      });
    }
  }

  Checkpoint _resolveCheckpoint(CheckpointProvider p) {
    for (final Checkpoint item in p.items) {
      if (item.id == widget.initialCheckpoint.id) {
        return item;
      }
    }
    return widget.initialCheckpoint;
  }

  static String _statusWord(String raw) {
    switch (CheckpointStatus.normalize(raw)) {
      case CheckpointStatus.closed:
        return 'مغلق';
      case CheckpointStatus.crowded:
        return 'أزمة';
      case CheckpointStatus.armyPresent:
        return 'جيش';
      case CheckpointStatus.settlersPresent:
        return 'مستوطنون';
      case CheckpointStatus.open:
      default:
        return 'سالك';
    }
  }

  static ({Color bg, Color fg, IconData icon}) _statusVisual(String raw) {
    switch (CheckpointStatus.normalize(raw)) {
      case CheckpointStatus.closed:
        return (
          bg: const Color(0xFFC62828),
          fg: Colors.white,
          icon: Icons.block_rounded,
        );
      case CheckpointStatus.crowded:
        return (
          bg: const Color(0xFFF9A825),
          fg: const Color(0xFF3E2723),
          icon: Icons.traffic_rounded,
        );
      case CheckpointStatus.armyPresent:
        return (
          bg: const Color(0xFFF59E0B),
          fg: const Color(0xFF422006),
          icon: Icons.military_tech_rounded,
        );
      case CheckpointStatus.settlersPresent:
        return (
          bg: const Color(0xFFC084FC),
          fg: const Color(0xFF3B0764),
          icon: Icons.home_work_rounded,
        );
      case CheckpointStatus.open:
      default:
        return (bg: _successGreen, fg: Colors.white, icon: Icons.check_rounded);
    }
  }

  static String _entranceTitle(Checkpoint c) {
    final String loc = c.location.trim();
    if (loc.isEmpty) {
      return 'للداخل';
    }
    return 'للداخل إلى ${cityDisplayNameAr(loc)}';
  }

  void _setTabIndex(int i) {
    setState(() => _tabIndex = i);
    _scheduleLocationResolveIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final CheckpointProvider cp = context.watch<CheckpointProvider>();
    final Checkpoint c = _resolveCheckpoint(cp);
    final String title = c.name.isEmpty ? 'بدون اسم' : c.name;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _DetailHeader(
                title: title,
                onClose: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CurrentStatusSummary(
                  checkpoint: c,
                  onEntranceBadgeTap: widget.bypassProximityCheck
                      ? () => showCheckpointStatusSheet(
                            context: context,
                            checkpoint: c,
                            direction: 'entrance',
                            updateSource: CheckpointUpdateSource.admin,
                          )
                      : null,
                  onExitBadgeTap: widget.bypassProximityCheck
                      ? () => showCheckpointStatusSheet(
                            context: context,
                            checkpoint: c,
                            direction: 'exit',
                            updateSource: CheckpointUpdateSource.admin,
                          )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TabPillsRow(
                  selectedIndex: _tabIndex,
                  onChanged: _setTabIndex,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: IndexedStack(
                    index: _tabIndex,
                    children: <Widget>[
                      _LatestUpdatesPanel(checkpoint: c),
                      _SendUpdatePanel(
                        key: ValueKey<String>(c.id),
                        checkpoint: c,
                        bypassProximityCheck: widget.bypassProximityCheck,
                      ),
                      _CheckpointInfoPanel(checkpoint: c),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: <Widget>[
          _RoundIconButton(
            backgroundColor: _headerBarBg,
            icon: Icons.close_rounded,
            iconColor: AppColors.textPrimaryLight,
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 44, height: 44),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _CurrentStatusSummary extends StatelessWidget {
  const _CurrentStatusSummary({
    required this.checkpoint,
    this.onEntranceBadgeTap,
    this.onExitBadgeTap,
  });

  final Checkpoint checkpoint;
  /// Null → badge is display-only (normal users); admin passes a tap handler.
  final VoidCallback? onEntranceBadgeTap;
  final VoidCallback? onExitBadgeTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: _surfaceCard,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _StatusHalf(
                  title: _CheckpointDetailScreenState._entranceTitle(
                    checkpoint,
                  ),
                  updatedAt: checkpoint.entranceUpdatedAt,
                  sourceFootnote: Checkpoint.updateSourceFootnoteAr(
                    checkpoint.entranceSource,
                  ),
                  onBadgeTap: onEntranceBadgeTap,
                  statusWord: _CheckpointDetailScreenState._statusWord(
                    checkpoint.entranceStatus,
                  ),
                  visual: _CheckpointDetailScreenState._statusVisual(
                    checkpoint.entranceStatus,
                  ),
                ),
              ),
              VerticalDivider(
                width: 24,
                thickness: 1,
                color: AppColors.borderSubtleLight,
              ),
              Expanded(
                child: _StatusHalf(
                  title: 'للخارج منها',
                  updatedAt: checkpoint.exitUpdatedAt,
                  sourceFootnote: Checkpoint.updateSourceFootnoteAr(
                    checkpoint.exitSource,
                  ),
                  onBadgeTap: onExitBadgeTap,
                  statusWord: _CheckpointDetailScreenState._statusWord(
                    checkpoint.exitStatus,
                  ),
                  visual: _CheckpointDetailScreenState._statusVisual(
                    checkpoint.exitStatus,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusHalf extends StatelessWidget {
  const _StatusHalf({
    required this.title,
    required this.updatedAt,
    this.onBadgeTap,
    required this.statusWord,
    required this.visual,
    this.sourceFootnote,
  });

  final String title;
  final DateTime? updatedAt;
  final String? sourceFootnote;
  final VoidCallback? onBadgeTap;
  final String statusWord;
  final ({Color bg, Color fg, IconData icon}) visual;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Builder(
            builder: (BuildContext context) {
              final Widget badge = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: visual.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      statusWord,
                      style: TextStyle(
                        color: visual.fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(visual.icon, color: visual.fg, size: 20),
                  ],
                ),
              );
              if (onBadgeTap == null) {
                return badge;
              }
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBadgeTap,
                  borderRadius: BorderRadius.circular(14),
                  child: badge,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          arabicRelativeOrClockSince(updatedAt),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textMutedLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (sourceFootnote != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            sourceFootnote!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMutedLight,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _TabPillsRow extends StatelessWidget {
  const _TabPillsRow({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _TabPill(
            label: 'آخر التحديثات',
            icon: Icons.history_rounded,
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabPill(
            label: 'أرسل تحديث',
            icon: Icons.send_rounded,
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabPill(
            label: 'معلومات الحاجز',
            icon: Icons.info_outline_rounded,
            selected: selectedIndex == 2,
            onTap: () => onChanged(2),
          ),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _accentBlue : _surfaceCard,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : AppColors.borderSubtleLight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textMutedLight,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMutedLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestUpdatesPanel extends StatelessWidget {
  const _LatestUpdatesPanel({required this.checkpoint});

  final Checkpoint checkpoint;

  List<_TimelineEntry> _buildEntries() {
    final String name = checkpoint.name.isEmpty
        ? 'الحاجز'
        : checkpoint.name.trim();
    final List<CheckpointHistoryEntry> hist = checkpoint.statusHistory;

    if (hist.isNotEmpty) {
      const int maxEntries = 6;
      return hist
          .take(maxEntries)
          .map((CheckpointHistoryEntry e) {
            final String wIn = _CheckpointDetailScreenState._statusWord(
              e.entranceStatus,
            );
            final String wOut = _CheckpointDetailScreenState._statusWord(
              e.exitStatus,
            );
            final String mainLine = wIn == wOut
                ? '$name — $wIn'
                : '$name — دخول: $wIn · خروج: $wOut';
            return _TimelineEntry(
              relativeTime: arabicRelativeOrClockSince(e.at),
              bodyLines: <String>[mainLine],
              footNote: Checkpoint.updateSourceFootnoteAr(e.source),
            );
          })
          .toList(growable: false);
    }
    final String wIn = _CheckpointDetailScreenState._statusWord(
      checkpoint.entranceStatus,
    );
    final String wOut = _CheckpointDetailScreenState._statusWord(
      checkpoint.exitStatus,
    );
    final DateTime? te = checkpoint.entranceUpdatedAt;
    final DateTime? tx = checkpoint.exitUpdatedAt;

    if (te == null && tx == null) {
      return <_TimelineEntry>[
        _TimelineEntry(
          relativeTime: 'لا وقت محدَّث',
          bodyLines: <String>['$name — لا يوجد سجل تحديثات بعد'],
          footNote: null,
        ),
      ];
    }

    final List<_TimelineEntry> out = <_TimelineEntry>[];

    if (te != null && tx != null) {
      final int diffMin = te.difference(tx).abs().inMinutes;
      if (diffMin < 3) {
        final DateTime t = te.isAfter(tx) ? te : tx;
        final String mainLine = wIn == wOut
            ? '$name $wIn'
            : '$name — دخول: $wIn · خروج: $wOut';
        out.add(
          _TimelineEntry(
            relativeTime: arabicRelativeOrClockSince(t),
            bodyLines: <String>[mainLine],
            footNote: null,
          ),
        );
      } else {
        if (te.isAfter(tx)) {
          out.add(
            _TimelineEntry(
              relativeTime: arabicRelativeOrClockSince(te),
              bodyLines: <String>['$name — للداخل: $wIn'],
              footNote: null,
            ),
          );
          out.add(
            _TimelineEntry(
              relativeTime: arabicRelativeOrClockSince(tx),
              bodyLines: <String>['$name — للخارج: $wOut'],
              footNote: null,
            ),
          );
        } else {
          out.add(
            _TimelineEntry(
              relativeTime: arabicRelativeOrClockSince(tx),
              bodyLines: <String>['$name — للخارج: $wOut'],
              footNote: null,
            ),
          );
          out.add(
            _TimelineEntry(
              relativeTime: arabicRelativeOrClockSince(te),
              bodyLines: <String>['$name — للداخل: $wIn'],
              footNote: null,
            ),
          );
        }
      }
    } else if (te != null) {
      out.add(
        _TimelineEntry(
          relativeTime: arabicRelativeOrClockSince(te),
          bodyLines: <String>['$name — للداخل: $wIn'],
          footNote: null,
        ),
      );
    } else {
      out.add(
        _TimelineEntry(
          relativeTime: arabicRelativeOrClockSince(tx),
          bodyLines: <String>['$name — للخارج: $wOut'],
          footNote: null,
        ),
      );
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final List<_TimelineEntry> entries = _buildEntries();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: _surfaceCard,
        child: Stack(
          children: <Widget>[
            Positioned(
              right: 18,
              top: 56,
              bottom: 20,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: _successGreen.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 28, 16),
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'التحديثات الأخيرة',
                    style: TextStyle(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TimelineCard(entry: e),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.relativeTime,
    required this.bodyLines,
    required this.footNote,
  });

  final String relativeTime;
  final List<String> bodyLines;
  final String? footNote;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            entry.relativeTime,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMutedLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...entry.bodyLines.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
          ),
          if (entry.footNote != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              entry.footNote!,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMutedLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// خيارات «أرسل تحديث» — تُطابق قيمَ [CheckpointStatus] في Firestore.
enum _SendUpdateOption { open, crowded, closed, armyPresent, settlersPresent }

extension on _SendUpdateOption {
  String get labelAr {
    switch (this) {
      case _SendUpdateOption.open:
        return 'سالك';
      case _SendUpdateOption.crowded:
        return 'أزمة';
      case _SendUpdateOption.closed:
        return 'مغلق';
      case _SendUpdateOption.armyPresent:
        return 'جيش';
      case _SendUpdateOption.settlersPresent:
        return 'مستوطنون';
    }
  }

  IconData get icon {
    switch (this) {
      case _SendUpdateOption.open:
        return Icons.check_rounded;
      case _SendUpdateOption.crowded:
        return Icons.traffic_rounded;
      case _SendUpdateOption.closed:
        return Icons.do_not_disturb_on_rounded;
      case _SendUpdateOption.armyPresent:
        return Icons.military_tech_rounded;
      case _SendUpdateOption.settlersPresent:
        return Icons.home_work_rounded;
    }
  }

  String get repoStatus {
    switch (this) {
      case _SendUpdateOption.closed:
        return CheckpointStatus.closed;
      case _SendUpdateOption.open:
        return CheckpointStatus.open;
      case _SendUpdateOption.crowded:
        return CheckpointStatus.crowded;
      case _SendUpdateOption.armyPresent:
        return CheckpointStatus.armyPresent;
      case _SendUpdateOption.settlersPresent:
        return CheckpointStatus.settlersPresent;
    }
  }
}

_SendUpdateOption _sendUpdateOptionFromCheckpoint(String raw) {
  switch (CheckpointStatus.normalize(raw)) {
    case CheckpointStatus.closed:
      return _SendUpdateOption.closed;
    case CheckpointStatus.crowded:
      return _SendUpdateOption.crowded;
    case CheckpointStatus.armyPresent:
      return _SendUpdateOption.armyPresent;
    case CheckpointStatus.settlersPresent:
      return _SendUpdateOption.settlersPresent;
    case CheckpointStatus.open:
    default:
      return _SendUpdateOption.open;
  }
}

class _SendUpdatePanel extends StatefulWidget {
  const _SendUpdatePanel({
    super.key,
    required this.checkpoint,
    this.bypassProximityCheck = false,
  });

  final Checkpoint checkpoint;
  final bool bypassProximityCheck;

  @override
  State<_SendUpdatePanel> createState() => _SendUpdatePanelState();
}

class _SendUpdatePanelState extends State<_SendUpdatePanel> {
  late _SendUpdateOption _entranceOption;
  late _SendUpdateOption _exitOption;
  final Set<String> _tags = <String>{};
  bool _submitting = false;

  /// Canonical keys aligned with Arabic chip labels (same order as before).
  static const List<String> _detailTagKeys = <String>[
    CheckpointReportTag.inspection,
    CheckpointReportTag.trafficAccident,
    CheckpointReportTag.trafficDensity,
    CheckpointReportTag.maintenance,
    CheckpointReportTag.badWeather,
  ];

  static const List<String> _detailTagLabelsAr = <String>[
    'تفتيش',
    'حادث سير',
    'كثافة سير',
    'أعمال صيانة',
    'طقس سيء',
  ];

  @override
  void initState() {
    super.initState();
    _entranceOption = _sendUpdateOptionFromCheckpoint(
      widget.checkpoint.entranceStatus,
    );
    _exitOption = _sendUpdateOptionFromCheckpoint(widget.checkpoint.exitStatus);
    _tags.addAll(widget.checkpoint.reportTags);
  }

  @override
  void didUpdateWidget(covariant _SendUpdatePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkpoint.id != widget.checkpoint.id) {
      _entranceOption = _sendUpdateOptionFromCheckpoint(
        widget.checkpoint.entranceStatus,
      );
      _exitOption = _sendUpdateOptionFromCheckpoint(
        widget.checkpoint.exitStatus,
      );
      _tags
        ..clear()
        ..addAll(widget.checkpoint.reportTags);
    }
  }

  String _entranceRowLabel() {
    final String loc = widget.checkpoint.location.trim();
    if (loc.isEmpty) {
      return 'للداخل ←';
    }
    return '${cityDisplayNameAr(loc)} ←';
  }

  bool _canSubmit(UserLocationProvider loc, Checkpoint c) {
    if (_submitting) {
      return false;
    }
    if (widget.bypassProximityCheck) {
      return true;
    }
    if (!c.hasCoordinates) {
      return true;
    }
    if (loc.resolving) {
      return false;
    }
    if (loc.errorMessageAr != null) {
      return false;
    }
    final pos = loc.position;
    if (pos == null) {
      return false;
    }
    final double? d = c.distanceKmFrom(pos.latitude, pos.longitude);
    if (d == null) {
      return false;
    }
    return d <= _kUpdateRadiusKm;
  }

  Future<void> _submit(BuildContext context) async {
    if (!await ensureCanMakeCheckpointChanges(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final CheckpointProvider provider = context.read<CheckpointProvider>();
    final Checkpoint c = widget.checkpoint;
    setState(() => _submitting = true);
    try {
      await provider.updateBothStatuses(
        c.id,
        entranceStatus: _entranceOption.repoStatus,
        exitStatus: _exitOption.repoStatus,
        tags: _tags.toList(),
        source: widget.bypassProximityCheck
            ? CheckpointUpdateSource.admin
            : CheckpointUpdateSource.user,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال التحديث')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر الإرسال: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserLocationProvider loc = context.watch<UserLocationProvider>();
    final Checkpoint c = widget.checkpoint;
    final bool statusCirclesEnabled = _canSubmit(loc, c);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: _surfaceCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _ProximityBanner(
                checkpoint: c,
                location: loc,
                bypassProximityCheck: widget.bypassProximityCheck,
                onRefresh: () => loc.resolve(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: <Widget>[
                  Text(
                    'شاركونا حالة الطريق 💛',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اختر الحالة لكل اتجاه',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMutedLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DirectionStatusPicker(
                    heading: _entranceRowLabel(),
                    value: _entranceOption,
                    enabled: statusCirclesEnabled,
                    onChanged: (v) => setState(() => _entranceOption = v),
                  ),
                  const SizedBox(height: 22),
                  _DirectionStatusPicker(
                    heading: 'للخارج ←',
                    value: _exitOption,
                    enabled: statusCirclesEnabled,
                    onChanged: (v) => setState(() => _exitOption = v),
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'تفاصيل إضافية:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: List<Widget>.generate(_detailTagKeys.length, (
                      int i,
                    ) {
                      final String key = _detailTagKeys[i];
                      final String labelAr = _detailTagLabelsAr[i];
                      final bool on = _tags.contains(key);
                      return FilterChip(
                        label: Text(labelAr),
                        selected: on,
                        onSelected: (bool v) {
                          setState(() {
                            if (v) {
                              _tags.add(key);
                            } else {
                              _tags.remove(key);
                            }
                          });
                        },
                        backgroundColor: _surfaceElevated,
                        selectedColor: _accentBlue.withValues(alpha: 0.35),
                        checkmarkColor: _accentBlue,
                        labelStyle: TextStyle(
                          color: on
                              ? AppColors.textPrimaryLight
                              : AppColors.textMutedLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: on ? _accentBlue : AppColors.borderSubtleLight,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: FilledButton(
                onPressed: _canSubmit(loc, c) ? () => _submit(context) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'إرسال التحديث',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProximityBanner extends StatelessWidget {
  const _ProximityBanner({
    required this.checkpoint,
    required this.location,
    required this.bypassProximityCheck,
    required this.onRefresh,
  });

  final Checkpoint checkpoint;
  final UserLocationProvider location;
  final bool bypassProximityCheck;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final Checkpoint c = checkpoint;
    final UserLocationProvider loc = location;

    String message;
    bool showGreenCheck = false;
    bool messageIsWarningRed = false;

    if (bypassProximityCheck) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.shellSurfaceTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentBlue.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.admin_panel_settings_rounded,
              color: _accentBlue,
              size: 22,
            ),
            Expanded(
              child: Text(
                'وضع الإدارة — يمكن إرسال التحديث دون التحقق من موقعك أو المسافة.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!c.hasCoordinates) {
      message = 'لا تتوفر إحداثيات لهذا الحاجز — لا يمكن التحقق من المسافة.';
      showGreenCheck = false;
      messageIsWarningRed = false;
    } else if (loc.resolving) {
      message = 'جاري تحديد موقعك…';
    } else if (loc.errorMessageAr != null) {
      message = loc.errorMessageAr!;
      messageIsWarningRed = true;
    } else if (loc.position == null) {
      message = 'اضغط «تحديث» لتحديد موقعك.';
      messageIsWarningRed = true;
    } else {
      final double? d = c.distanceKmFrom(
        loc.position!.latitude,
        loc.position!.longitude,
      );
      if (d == null) {
        message = 'تعذّر حساب المسافة.';
        messageIsWarningRed = true;
      } else if (d <= _kUpdateRadiusKm) {
        message = 'أنت ضمن نطاق $_kUpdateRadiusKm كم — يمكنك إرسال التحديث.';
        showGreenCheck = true;
      } else {
        message = 'يجب أن تكون ضمن نطاق $_kUpdateRadiusKm كم للتحديث';
        messageIsWarningRed = true;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: <Widget>[
          if (showGreenCheck)
            const Icon(
              Icons.check_circle_rounded,
              color: _successGreen,
              size: 22,
            )
          else
            const SizedBox(width: 22),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: messageIsWarningRed
                    ? Colors.red.shade700
                    : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: _accentBlue,
              backgroundColor: _accentBlue.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: loc.resolving ? null : onRefresh,
            icon: loc.resolving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accentBlue,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'تحديث',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionStatusPicker extends StatelessWidget {
  const _DirectionStatusPicker({
    required this.heading,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String heading;
  final _SendUpdateOption value;
  final bool enabled;
  final ValueChanged<_SendUpdateOption> onChanged;

  static const List<_SendUpdateOption> _options = <_SendUpdateOption>[
    _SendUpdateOption.open,
    _SendUpdateOption.crowded,
    _SendUpdateOption.closed,
    _SendUpdateOption.armyPresent,
    _SendUpdateOption.settlersPresent,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          heading,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          textDirection: TextDirection.rtl,
          children: _options.map((_SendUpdateOption o) {
            return Expanded(
              child: _CircleStatusOption(
                option: o,
                selected: value == o,
                enabled: enabled,
                onTap: () => onChanged(o),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CircleStatusOption extends StatelessWidget {
  const _CircleStatusOption({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _SendUpdateOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = selected ? Colors.white : AppColors.textMutedLight;
    final Color labelColor = selected
        ? AppColors.textPrimaryLight
        : AppColors.textMutedLight;
    final Widget column = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? _accentBlue.withValues(alpha: 0.35)
                  : _surfaceElevated,
              border: Border.all(
                color: selected ? _accentBlue : AppColors.borderSubtleLight,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(option.icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            option.labelAr,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
    if (!enabled) {
      return column;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: column,
    );
  }
}

class _CheckpointInfoPanel extends StatelessWidget {
  const _CheckpointInfoPanel({required this.checkpoint});

  final Checkpoint checkpoint;

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(content: Text('هذه الخدمة ستتوفر قريبا')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: _surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtleLight),
        ),
        child: Column(
          key: ValueKey<String>(checkpoint.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ReportErrorCard(onTap: () => _soon(context)),
            const SizedBox(height: 14),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      textDirection: TextDirection.rtl,
                      children: <Widget>[
                        Expanded(
                          child: _InfoActionTile(
                            label: 'وقت الفتح والإغلاق',
                            icon: Icons.schedule_rounded,
                            onTap: () => _soon(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoActionTile(
                            label: 'الموقع',
                            icon: Icons.location_on_rounded,
                            onTap: () => _soon(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _InfoActionTile(
                      label: 'الطرق البديلة',
                      icon: Icons.alt_route_rounded,
                      onTap: () => _soon(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportErrorCard extends StatelessWidget {
  const _ReportErrorCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: _accentBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'بلّغ عن خطأ',
                      style: TextStyle(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ساعدنا بتحسين بيانات الحاجز',
                      style: TextStyle(
                        color: AppColors.textMutedLight,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textMutedLight,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoActionTile extends StatelessWidget {
  const _InfoActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.solidBlueIconCircle = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool solidBlueIconCircle;

  @override
  Widget build(BuildContext context) {
    final Widget iconChild = solidBlueIconCircle
        ? Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _accentBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          )
        : Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentBlue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _accentBlue, size: 22),
          );

    return Material(
      color: _surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              iconChild,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
