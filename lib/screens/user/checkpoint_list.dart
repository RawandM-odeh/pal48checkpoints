import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/saved_checkpoints_provider.dart';
import '../../providers/user_location_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/ar_relative_time.dart';
import '../../utils/checkpoint_search.dart';
import '../../utils/guest_session.dart';
import '../widgets/checkpoint_card.dart';
import 'checkpoint_detail_screen.dart';

typedef _NearbyRow = ({Checkpoint checkpoint, double? distanceKm});

/// Subtitle suffix when GPS distance is known (Haversine).
const String _kLocationNotAvailableLabel = 'Location not available';

/// Max checkpoints shown in «أقرب الحواجز» (nearest first after sort).
const int _kNearestListMaxItems = 20;

Future<void> _toggleSavedLoggedInIfAllowed(
  BuildContext context,
  SavedCheckpointsProvider saved,
  String checkpointId,
) async {
  if (!await ensureLoggedInForSaved(context)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  saved.toggle(checkpointId);
}

String _formatDistanceAwayKm(double km) {
  if (km < 10) {
    return '${km.toStringAsFixed(1)} km away';
  }
  return '${km.round()} km away';
}

/// قائمة المستخدم: كل صف حاجزان، وبطاقات بشكل عريض (دخول | خروج).
/// وضع «الأقرب» يُفعّل من شريط الفلاتر؛ الترتيب حسب المسافة (Haversine).
class CheckpointList extends StatefulWidget {
  const CheckpointList({
    super.key,
    required this.nearestMode,
    required this.onNearestModeChanged,
    this.searchQuery = '',
    this.compactMode = false,
    this.cityFilter,
  });

  final bool nearestMode;
  final ValueChanged<bool> onNearestModeChanged;
  final String searchQuery;
  final bool compactMode;
  final String? cityFilter;

  @override
  State<CheckpointList> createState() => _CheckpointListState();
}

class _CheckpointListState extends State<CheckpointList> {
  UserLocationProvider? _userLoc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final UserLocationProvider next = context.read<UserLocationProvider>();
    if (_userLoc != next) {
      _userLoc?.removeListener(_onUserLocationChanged);
      _userLoc = next;
      _userLoc!.addListener(_onUserLocationChanged);
    }
  }

  @override
  void dispose() {
    _userLoc?.removeListener(_onUserLocationChanged);
    super.dispose();
  }

  void _onUserLocationChanged() {
    if (!mounted || !widget.nearestMode) {
      return;
    }
    final UserLocationProvider loc = _userLoc!;
    if (loc.resolving) {
      return;
    }
    if (loc.position != null) {
      return;
    }
    final String? err = loc.errorMessageAr;
    if (err == null) {
      return;
    }
    loc.clearError();
    widget.onNearestModeChanged(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    });
  }

  List<Checkpoint> _filtered(List<Checkpoint> items) {
    final String q = widget.searchQuery.trim().toLowerCase();
    Iterable<Checkpoint> out = items;
    final String? cityFilter = widget.cityFilter;
    if (cityFilter != null && cityFilter.trim().isNotEmpty) {
      final String cityNorm = cityFilter.trim().toLowerCase();
      out = out.where(
        (Checkpoint c) => c.location.trim().toLowerCase() == cityNorm,
      );
    }
    if (q.isNotEmpty) {
      out = out.where((Checkpoint c) => checkpointMatchesUserSearch(c, q));
    }
    final List<Checkpoint> list = out.toList(growable: false);
    list.sort(
      (Checkpoint a, Checkpoint b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  }

  double _userTwinCardOuterHeight({required bool hasCaption}) {
    if (widget.compactMode) {
      return hasCaption ? 198.0 : 180.0;
    }
    return hasCaption ? 214.0 : 194.0;
  }

  /// بطاقة بعرض أفضل (عنوان + دخول/خروج جنب بعض) كمرجع الإدارة لكن بلون فاتح.
  Widget _userCheckpointCard(
    BuildContext context,
    Checkpoint c,
    SavedCheckpointsProvider saved, {
    String? captionBelowTitle,
  }) {
    final String? trimmed = captionBelowTitle?.trim();
    final bool hasCaption = trimmed != null && trimmed.isNotEmpty;
    final double stripH = widget.compactMode
        ? CheckpointCardStyle.userTwinRowStripHeightCompact
        : CheckpointCardStyle.userTwinRowStripHeight;

    return SizedBox(
      height: _userTwinCardOuterHeight(hasCaption: hasCaption),
      child: CheckpointCard(
        checkpoint: c,
        appearance: CheckpointCardAppearance.light,
        directionStripHeight: stripH,
        detailCaption: hasCaption ? trimmed : null,
        trailing: const SizedBox(width: 20),
        headerEnd: IconButton(
          tooltip: 'مثبتة',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 28,
          ),
          onPressed: () =>
              _toggleSavedLoggedInIfAllowed(context, saved, c.id),
          icon: Icon(
            saved.isSaved(c.id)
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            size: 22,
            color: saved.isSaved(c.id)
                ? CheckpointCardStyle.arrowBlue
                : AppColors.textMutedLight,
          ),
        ),
        onStatusBadgeTap: (String direction) {
          showCheckpointStatusSheet(
            context: context,
            checkpoint: c,
            direction: direction,
          );
        },
        onCardTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CheckpointDetailScreen(initialCheckpoint: c),
            ),
          );
        },
      ),
    );
  }

  /// حاجزان في كل صف؛ [captionFor] اختياري (وضع «الأقرب»: وقت + مسافة تقريبية).
  Widget _buildTwoColumnRows({
    required BuildContext context,
    required List<Checkpoint> checkpoints,
    required SavedCheckpointsProvider saved,
    String? Function(Checkpoint c)? captionFor,
  }) {
    final double gap = widget.compactMode ? 8 : 10;
    final int rowCount = (checkpoints.length + 1) >> 1;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePaddingH,
        AppLayout.spaceSm,
        AppLayout.pagePaddingH,
        AppLayout.spaceSm,
      ),
      itemCount: rowCount,
      itemBuilder: (BuildContext context, int rowIndex) {
        final int i = rowIndex * 2;
        final Checkpoint a = checkpoints[i];
        final Checkpoint? b =
            i + 1 < checkpoints.length ? checkpoints[i + 1] : null;
        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex < rowCount - 1 ? gap : 0),
          // تجنّب [CrossAxisAlignment.stretch] مع بطاقات بـ [Expanded] داخل عمود ثابت
          // (مشاكل قياس على الويب مع قائمة فارغة).
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Expanded(
                child: _userCheckpointCard(
                  context,
                  a,
                  saved,
                  captionBelowTitle: captionFor?.call(a),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: b != null
                    ? _userCheckpointCard(
                        context,
                        b,
                        saved,
                        captionBelowTitle: captionFor?.call(b),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_NearbyRow> _rowsNearUser(
    List<Checkpoint> prefiltered,
    double userLat,
    double userLon,
  ) {
    final List<_NearbyRow> rows = prefiltered.map((Checkpoint c) {
      final double? d = c.distanceKmFrom(userLat, userLon);
      return (checkpoint: c, distanceKm: d);
    }).toList();
    rows.sort((_NearbyRow a, _NearbyRow b) {
      final double? da = a.distanceKm;
      final double? db = b.distanceKm;
      if (da != null && db != null) {
        return da.compareTo(db);
      }
      if (da != null) {
        return -1;
      }
      if (db != null) {
        return 1;
      }
      return a.checkpoint.name.toLowerCase().compareTo(
        b.checkpoint.name.toLowerCase(),
      );
    });
    if (rows.length <= _kNearestListMaxItems) {
      return rows;
    }
    return rows.sublist(0, _kNearestListMaxItems);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckpointProvider provider = context.watch<CheckpointProvider>();
    final UserLocationProvider loc = context.watch<UserLocationProvider>();
    final SavedCheckpointsProvider saved = context.watch<SavedCheckpointsProvider>();

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

    if (!provider.loading && provider.items.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.pagePaddingH,
            AppLayout.spaceSm,
            AppLayout.pagePaddingH,
            AppLayout.spaceSm,
          ),
          children: <Widget>[
            Center(
              child: Text(
                'لا توجد حواجز في الخادم',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textMutedLight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<Checkpoint> citySearchFiltered = _filtered(provider.items);

    if (!widget.nearestMode) {
      if (citySearchFiltered.isEmpty) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppLayout.pagePaddingH,
              AppLayout.spaceSm,
              AppLayout.pagePaddingH,
              AppLayout.spaceSm,
            ),
            children: <Widget>[
              Center(
                child: Text(
                  'لا توجد نقاط تطابق الفلتر أو البحث',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textMutedLight,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Directionality(
        textDirection: TextDirection.rtl,
        child: _buildTwoColumnRows(
          context: context,
          checkpoints: citySearchFiltered,
          saved: saved,
        ),
      );
    }

    // nearestMode == true
    final Position? pos = loc.position;
    if (loc.resolving || pos == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.pagePaddingH,
            AppLayout.spaceSm,
            AppLayout.pagePaddingH,
            AppLayout.spaceSm,
          ),
          children: <Widget>[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 18),
            Text(
              'جاري تحديد موقعك لترتيب الحواجز حسب القرب…',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMutedLight,
              ),
            ),
          ],
        ),
      );
    }

    final double userLat = pos.latitude;
    final double userLon = pos.longitude;

    final List<_NearbyRow> rows = _rowsNearUser(
      citySearchFiltered,
      userLat,
      userLon,
    );

    if (rows.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.pagePaddingH,
            AppLayout.spaceSm,
            AppLayout.pagePaddingH,
            AppLayout.spaceSm,
          ),
          children: <Widget>[
            Center(
              child: Text(
                'لا توجد نقاط تطابق الفلتر أو البحث',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textMutedLight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final Map<String, String> nearestSubtitleById = <String, String>{};
    for (final _NearbyRow r in rows) {
      final Checkpoint c = r.checkpoint;
      final String rel = arabicRelativeSince(c.latestDirectionalUpdate);
      nearestSubtitleById[c.id] = r.distanceKm != null
          ? '$rel · ${_formatDistanceAwayKm(r.distanceKm!)}'
          : '$rel · $_kLocationNotAvailableLabel';
    }

    final List<Checkpoint> nearestOrdered =
        rows.map((_NearbyRow r) => r.checkpoint).toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: _buildTwoColumnRows(
        context: context,
        checkpoints: nearestOrdered,
        saved: saved,
        captionFor: (Checkpoint c) => nearestSubtitleById[c.id],
      ),
    );
  }
}
