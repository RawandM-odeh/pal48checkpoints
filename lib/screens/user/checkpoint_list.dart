import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/favorite_checkpoints_provider.dart';
import '../../providers/saved_checkpoints_provider.dart';
import '../../providers/user_location_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/ar_relative_time.dart';
import '../../utils/checkpoint_search.dart';
import '../../utils/guest_session.dart';
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

  List<Widget> _buildBrowseItems(
    BuildContext context,
    List<Checkpoint> filtered,
    FavoriteCheckpointsProvider favorites,
    SavedCheckpointsProvider saved,
  ) {
    final List<Widget> tiles = <Widget>[];
    for (int i = 0; i < filtered.length; i++) {
      final Checkpoint c = filtered[i];
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppLayout.pagePaddingH,
            0,
            AppLayout.pagePaddingH,
            widget.compactMode ? 8 : 10,
          ),
          child: ReferenceCheckpointTile(
            checkpoint: c,
            compact: widget.compactMode,
            stripColor: checkpointStripColor(c),
            subtitle: arabicRelativeSince(c.latestDirectionalUpdate),
            isSaved: saved.isSaved(c.id),
            onSavedTap: () =>
                _toggleSavedLoggedInIfAllowed(context, saved, c.id),
            isFavorite: favorites.isFavorite(c.id),
            onFavoriteTap: () =>
                _toggleFavoriteLoggedInIfAllowed(context, favorites, c.id),
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
    SavedCheckpointsProvider saved,
  ) {
    final List<Widget> tiles = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      final _NearbyRow row = rows[i];
      final Checkpoint c = row.checkpoint;
      final String rel = arabicRelativeSince(c.latestDirectionalUpdate);
      final String subtitle = row.distanceKm != null
          ? '$rel · ${_formatDistanceAwayKm(row.distanceKm!)}'
          : '$rel · $_kLocationNotAvailableLabel';
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppLayout.pagePaddingH,
            0,
            AppLayout.pagePaddingH,
            widget.compactMode ? 8 : 10,
          ),
          child: ReferenceCheckpointTile(
            checkpoint: c,
            compact: widget.compactMode,
            stripColor: checkpointStripColor(c),
            subtitle: subtitle,
            isSaved: saved.isSaved(c.id),
            onSavedTap: () =>
                _toggleSavedLoggedInIfAllowed(context, saved, c.id),
            isFavorite: favorites.isFavorite(c.id),
            onFavoriteTap: () =>
                _toggleFavoriteLoggedInIfAllowed(context, favorites, c.id),
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
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckpointProvider provider = context.watch<CheckpointProvider>();
    final UserLocationProvider loc = context.watch<UserLocationProvider>();
    final FavoriteCheckpointsProvider favorites = context
        .watch<FavoriteCheckpointsProvider>();
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
      final List<Widget> body = _buildBrowseItems(
        context,
        citySearchFiltered,
        favorites,
        saved,
      );
      if (body.isEmpty) {
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppLayout.spaceSm,
            0,
            AppLayout.spaceSm,
          ),
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

    final List<Widget> children =
        _buildNearestItems(context, rows, favorites, saved);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          0,
          AppLayout.spaceSm,
          0,
          AppLayout.spaceSm,
        ),
        children: children,
      ),
    );
  }
}
