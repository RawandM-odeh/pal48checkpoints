import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/favorite_checkpoints_provider.dart';
import '../../providers/user_location_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/ar_relative_time.dart';
import '../../utils/guest_session.dart';
import '../widgets/checkpoint_card.dart';
import '../widgets/reference_checkpoint_tile.dart';
import 'checkpoint_detail_screen.dart';

typedef _NearbyRow = ({Checkpoint checkpoint, double? distanceKm});

/// Subtitle suffix when GPS distance is known (Haversine).
const String _kLocationNotAvailableLabel = 'Location not available';

/// Max checkpoints shown in «أقرب الحواجز» (nearest first after sort).
const int _kNearestListMaxItems = 20;

Future<void> _toggleFavoriteLoggedInIfAllowed(
  BuildContext context,
  FavoriteCheckpointsProvider favorites,
  String checkpointId,
) async {
  if (!await ensureLoggedInForFavorites(context)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  favorites.toggle(checkpointId);
}

String _formatDistanceAwayKm(double km) {
  if (km < 10) {
    return '${km.toStringAsFixed(1)} km away';
  }
  return '${km.round()} km away';
}

DateTime? _latestUpdate(Checkpoint c) {
  final DateTime? a = c.entranceUpdatedAt;
  final DateTime? b = c.exitUpdatedAt;
  if (a != null && b != null) {
    return a.isAfter(b) ? a : b;
  }
  return a ?? b;
}

/// قائمة عمودية بنفس أسلوب المرجع.
/// وضع «الأقرب» يُفعّل من شريط الفلاتر في الشاشة الرئيسية؛ الترتيب حسب المسافة (Haversine).
class CheckpointList extends StatefulWidget {
  const CheckpointList({
    super.key,
    required this.nearestMode,
    required this.onNearestModeChanged,
    this.searchQuery = '',
    this.compactMode = false,
    this.cityFilter,
    this.promoVisible = true,
    this.onDismissPromo,
    this.onActivatePromo,
  });

  final bool nearestMode;
  final ValueChanged<bool> onNearestModeChanged;
  final String searchQuery;
  final bool compactMode;
  final String? cityFilter;
  final bool promoVisible;
  final VoidCallback? onDismissPromo;
  final VoidCallback? onActivatePromo;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err)));
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
      out = out.where((Checkpoint c) => _checkpointMatchesSearch(c, q));
    }
    final List<Checkpoint> list = out.toList(growable: false);
    list.sort(
      (Checkpoint a, Checkpoint b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  }

  /// Matches checkpoint name and directional status (المدينة تُختار من القائمة أعلاه).
  static bool _checkpointMatchesSearch(Checkpoint c, String q) {
    if (c.name.toLowerCase().contains(q)) {
      return true;
    }
    final String en = CheckpointStatus.normalize(c.entranceStatus);
    final String ex = CheckpointStatus.normalize(c.exitStatus);
    if (en.contains(q) || ex.contains(q)) {
      return true;
    }
    final String enAr = CheckpointStatus.labelAr(en).toLowerCase();
    final String exAr = CheckpointStatus.labelAr(ex).toLowerCase();
    if (enAr.contains(q) || exAr.contains(q)) {
      return true;
    }
    if (CheckpointStatus.badgeLabelAr(en).toLowerCase().contains(q) ||
        CheckpointStatus.badgeLabelAr(ex).toLowerCase().contains(q)) {
      return true;
    }
    return false;
  }

  List<Widget> _buildBrowseItems(
    BuildContext context,
    List<Checkpoint> filtered,
    FavoriteCheckpointsProvider favorites,
  ) {
    final List<Widget> tiles = <Widget>[];
    bool promoInserted = false;
    for (int i = 0; i < filtered.length; i++) {
      if (widget.promoVisible &&
          !promoInserted &&
          filtered.length >= 2 &&
          i == 1) {
        tiles.add(
          _RoadSummaryPromoCard(
            onLater: widget.onDismissPromo,
            onActivate: widget.onActivatePromo,
          ),
        );
        promoInserted = true;
      }
      final Checkpoint c = filtered[i];
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            widget.compactMode ? 8 : 10,
          ),
          child: ReferenceCheckpointTile(
            checkpoint: c,
            compact: widget.compactMode,
            stripColor: checkpointStripColor(c),
            subtitle: arabicRelativeSince(_latestUpdate(c)),
            isFavorite: favorites.isFavorite(c.id),
            onFavoriteTap: () => _toggleFavoriteLoggedInIfAllowed(
              context,
              favorites,
              c.id,
            ),
            onDirectionTap: (String direction) {
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
        ),
      );
    }
    if (widget.promoVisible && filtered.length == 1) {
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            widget.compactMode ? 8 : 10,
          ),
          child: _RoadSummaryPromoCard(
            onLater: widget.onDismissPromo,
            onActivate: widget.onActivatePromo,
          ),
        ),
      );
    }
    return tiles;
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

  List<Widget> _buildNearestItems(
    BuildContext context,
    List<_NearbyRow> rows,
    FavoriteCheckpointsProvider favorites,
  ) {
    final List<Widget> tiles = <Widget>[];
    bool promoInserted = false;
    for (int i = 0; i < rows.length; i++) {
      if (widget.promoVisible &&
          !promoInserted &&
          rows.length >= 2 &&
          i == 1) {
        tiles.add(
          _RoadSummaryPromoCard(
            onLater: widget.onDismissPromo,
            onActivate: widget.onActivatePromo,
          ),
        );
        promoInserted = true;
      }
      final _NearbyRow row = rows[i];
      final Checkpoint c = row.checkpoint;
      final String rel = arabicRelativeSince(_latestUpdate(c));
      final String subtitle = row.distanceKm != null
          ? '$rel · ${_formatDistanceAwayKm(row.distanceKm!)}'
          : '$rel · $_kLocationNotAvailableLabel';
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            widget.compactMode ? 8 : 10,
          ),
          child: ReferenceCheckpointTile(
            checkpoint: c,
            compact: widget.compactMode,
            stripColor: checkpointStripColor(c),
            subtitle: subtitle,
            isFavorite: favorites.isFavorite(c.id),
            onFavoriteTap: () => _toggleFavoriteLoggedInIfAllowed(
              context,
              favorites,
              c.id,
            ),
            onDirectionTap: (String direction) {
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
        ),
      );
    }
    if (widget.promoVisible && rows.length == 1) {
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            widget.compactMode ? 8 : 10,
          ),
          child: _RoadSummaryPromoCard(
            onLater: widget.onDismissPromo,
            onActivate: widget.onActivatePromo,
          ),
        ),
      );
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckpointProvider provider = context.watch<CheckpointProvider>();
    final UserLocationProvider loc = context.watch<UserLocationProvider>();
    final FavoriteCheckpointsProvider favorites = context
        .watch<FavoriteCheckpointsProvider>();

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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
      final List<Widget> body = _buildBrowseItems(
        context,
        citySearchFiltered,
        favorites,
      );
      if (body.isEmpty) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          children: body,
        ),
      );
    }

    // nearestMode == true
    final Position? pos = loc.position;
    if (loc.resolving || pos == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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

    final List<Widget> children = _buildNearestItems(context, rows, favorites);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: children,
      ),
    );
  }
}

class _RoadSummaryPromoCard extends StatelessWidget {
  const _RoadSummaryPromoCard({
    required this.onLater,
    required this.onActivate,
  });

  final VoidCallback? onLater;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ReferenceCheckpointTileTheme.cardBg,
          border: Border.all(color: AppColors.borderSubtleLight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          textDirection: TextDirection.rtl,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ReferenceCheckpointTileTheme.primaryBlue.withValues(
                  alpha: 0.2,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_2_outlined,
                color: ReferenceCheckpointTileTheme.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'اشعارات بملخص الطريق',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'في الوقت المناسب لك!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMutedLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              ReferenceCheckpointTileTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onActivate,
                        child: const Text('تفعيل'),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: onLater,
                        child: const Text('لاحقاً'),
                      ),
                    ],
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
