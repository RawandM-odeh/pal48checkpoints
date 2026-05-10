import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/user_location_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/ar_relative_time.dart';
import '../widgets/checkpoint_card.dart';
import '../widgets/reference_checkpoint_tile.dart';
import 'checkpoint_detail_screen.dart';

typedef _NearbyRow = ({Checkpoint checkpoint, double distanceKm});

/// قائمة عمودية بنفس أسلوب المرجع.
/// - **كل الحواجز:** مدينة + بحث بدون الحاجة لـ GPS.
/// - **أقرب الحواجز:** يحتاج إذن موقع وإحداثيات على كل حاجز.
class CheckpointList extends StatelessWidget {
  const CheckpointList({
    super.key,
    required this.nearbyRadiusKm,
    required this.nearestMode,
    required this.onNearestModeChanged,
    this.searchQuery = '',
    this.compactMode = false,
    this.cityFilter,
    this.promoVisible = true,
    this.onDismissPromo,
    this.onActivatePromo,
  });

  final double nearbyRadiusKm;
  final bool nearestMode;
  final ValueChanged<bool> onNearestModeChanged;
  final String searchQuery;
  final bool compactMode;
  final String? cityFilter;
  final bool promoVisible;
  final VoidCallback? onDismissPromo;
  final VoidCallback? onActivatePromo;

  static String _formatDistanceKm(double km) {
    if (km < 10) {
      return '${km.toStringAsFixed(1)} كم';
    }
    return '${km.round()} كم';
  }

  static DateTime? _latestUpdate(Checkpoint c) {
    final DateTime? a = c.entranceUpdatedAt;
    final DateTime? b = c.exitUpdatedAt;
    if (a != null && b != null) {
      return a.isAfter(b) ? a : b;
    }
    return a ?? b;
  }

  List<Checkpoint> _filtered(List<Checkpoint> items) {
    final String q = searchQuery.trim().toLowerCase();
    Iterable<Checkpoint> out = items;
    if (cityFilter != null && cityFilter!.trim().isNotEmpty) {
      final String cityNorm = cityFilter!.trim().toLowerCase();
      out = out.where(
        (Checkpoint c) => c.location.trim().toLowerCase() == cityNorm,
      );
    }
    if (q.isNotEmpty) {
      out = out.where(
        (Checkpoint c) => c.name.toLowerCase().contains(q),
      );
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
  ) {
    final List<Widget> tiles = <Widget>[];
    bool promoInserted = false;
    for (int i = 0; i < filtered.length; i++) {
      if (promoVisible &&
          !promoInserted &&
          filtered.length >= 2 &&
          i == 1) {
        tiles.add(_RoadSummaryPromoCard(
          onLater: onDismissPromo,
          onActivate: onActivatePromo,
        ));
        promoInserted = true;
      }
      final Checkpoint c = filtered[i];
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, compactMode ? 8 : 10),
          child: ReferenceCheckpointTile(
            checkpoint: c,
            compact: compactMode,
            stripColor: checkpointStripColor(c),
            subtitle: arabicRelativeSince(_latestUpdate(c)),
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
                  builder: (_) =>
                      CheckpointDetailScreen(initialCheckpoint: c),
                ),
              );
            },
          ),
        ),
      );
    }
    if (promoVisible && filtered.length == 1) {
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, compactMode ? 8 : 10),
          child: _RoadSummaryPromoCard(
            onLater: onDismissPromo,
            onActivate: onActivatePromo,
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
    final List<_NearbyRow> rows = <_NearbyRow>[];
    for (final Checkpoint c in prefiltered) {
      final double? d = c.distanceKmFrom(userLat, userLon);
      if (d != null && d <= nearbyRadiusKm) {
        rows.add((checkpoint: c, distanceKm: d));
      }
    }
    rows.sort(
      (_NearbyRow a, _NearbyRow b) =>
          a.distanceKm.compareTo(b.distanceKm),
    );
    return rows;
  }

  List<Widget> _buildItems(
    BuildContext context,
    List<_NearbyRow> rows,
  ) {
    final List<Widget> tiles = <Widget>[];
    bool promoInserted = false;
    for (int i = 0; i < rows.length; i++) {
      if (promoVisible &&
          !promoInserted &&
          rows.length >= 2 &&
          i == 1) {
        tiles.add(_RoadSummaryPromoCard(
          onLater: onDismissPromo,
          onActivate: onActivatePromo,
        ));
        promoInserted = true;
      }
      final _NearbyRow row = rows[i];
      final Checkpoint c = row.checkpoint;
      final String subtitle =
          '${arabicRelativeSince(_latestUpdate(c))} · ${_formatDistanceKm(row.distanceKm)}';
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, compactMode ? 8 : 10),
          child: ReferenceCheckpointTile(
            checkpoint: c,
            compact: compactMode,
            stripColor: checkpointStripColor(c),
            subtitle: subtitle,
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
                  builder: (_) =>
                      CheckpointDetailScreen(initialCheckpoint: c),
                ),
              );
            },
          ),
        ),
      );
    }
    if (promoVisible && rows.length == 1) {
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, compactMode ? 8 : 10),
          child: _RoadSummaryPromoCard(
            onLater: onDismissPromo,
            onActivate: onActivatePromo,
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
            _ListModeBar(
              nearestMode: nearestMode,
              onNearestModeChanged: onNearestModeChanged,
              onRequestLocation: () =>
                  context.read<UserLocationProvider>().resolve(),
            ),
            const SizedBox(height: 24),
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

    final List<Checkpoint> citySearchFiltered =
        _filtered(provider.items);

    if (!nearestMode) {
      final List<Widget> body = _buildBrowseItems(context, citySearchFiltered);
      if (body.isEmpty) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: <Widget>[
              _ListModeBar(
                nearestMode: nearestMode,
                onNearestModeChanged: onNearestModeChanged,
                onRequestLocation: () =>
                    context.read<UserLocationProvider>().resolve(),
              ),
              const SizedBox(height: 24),
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
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: _ListModeBar(
                nearestMode: nearestMode,
                onNearestModeChanged: onNearestModeChanged,
                onRequestLocation: () =>
                    context.read<UserLocationProvider>().resolve(),
              ),
            ),
            ...body,
          ],
        ),
      );
    }

    // nearestMode == true
    if (loc.resolving) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          children: <Widget>[
            _ListModeBar(
              nearestMode: nearestMode,
              onNearestModeChanged: onNearestModeChanged,
              onRequestLocation: () =>
                  context.read<UserLocationProvider>().resolve(),
            ),
            const SizedBox(height: 32),
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

    if (loc.errorMessageAr != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          children: <Widget>[
            _ListModeBar(
              nearestMode: nearestMode,
              onNearestModeChanged: onNearestModeChanged,
              onRequestLocation: () =>
                  context.read<UserLocationProvider>().resolve(),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.location_off_rounded,
              size: 48,
              color: theme.colorScheme.error.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 16),
            Text(
              loc.errorMessageAr!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<UserLocationProvider>().resolve(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => onNearestModeChanged(false),
              child: const Text('العودة لعرض كل الحواجز'),
            ),
          ],
        ),
      );
    }

    final Position? pos = loc.position;
    if (pos == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          children: <Widget>[
            _ListModeBar(
              nearestMode: nearestMode,
              onNearestModeChanged: onNearestModeChanged,
              onRequestLocation: () =>
                  context.read<UserLocationProvider>().resolve(),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'لم يُحدَّد الموقع',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textMutedLight,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onNearestModeChanged(false),
              child: const Text('عرض كل الحواجز بدون موقع'),
            ),
          ],
        ),
      );
    }

    final double userLat = pos.latitude;
    final double userLon = pos.longitude;

    final bool anyCoords =
        provider.items.any((Checkpoint c) => c.hasCoordinates);
    if (!anyCoords) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          children: <Widget>[
            _ListModeBar(
              nearestMode: nearestMode,
              onNearestModeChanged: onNearestModeChanged,
              onRequestLocation: () =>
                  context.read<UserLocationProvider>().resolve(),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد إحداثيات على الحواجز في قاعدة البيانات.\n'
              'أضف latitude و longitude أو geo لكل حاجز.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => onNearestModeChanged(false),
              child: const Text('عرض كل الحواجز'),
            ),
          ],
        ),
      );
    }

    final List<_NearbyRow> rows =
        _rowsNearUser(citySearchFiltered, userLat, userLon);

    if (rows.isEmpty) {
      final bool hadCandidatesOutsideRadius = citySearchFiltered
          .where((Checkpoint c) => c.hasCoordinates)
          .isNotEmpty;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          children: <Widget>[
            _ListModeBar(
              nearestMode: nearestMode,
              onNearestModeChanged: onNearestModeChanged,
              onRequestLocation: () =>
                  context.read<UserLocationProvider>().resolve(),
            ),
            const SizedBox(height: 24),
            Text(
              hadCandidatesOutsideRadius
                  ? 'لا توجد حواجز ضمن نطاق ${nearbyRadiusKm.round()} كم من موقعك ضمن الفلتر الحالي.'
                  : 'لا توجد نقاط ضمن النطاق.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () =>
                  context.read<UserLocationProvider>().resolve(),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('تحديث الموقع'),
            ),
            TextButton(
              onPressed: () => onNearestModeChanged(false),
              child: const Text('عرض كل الحواجز'),
            ),
          ],
        ),
      );
    }

    final List<Widget> children = _buildItems(context, rows);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: _ListModeBar(
              nearestMode: nearestMode,
              onNearestModeChanged: onNearestModeChanged,
              onRequestLocation: () =>
                  context.read<UserLocationProvider>().resolve(),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ListModeBar extends StatelessWidget {
  const _ListModeBar({
    required this.nearestMode,
    required this.onNearestModeChanged,
    required this.onRequestLocation,
  });

  final bool nearestMode;
  final ValueChanged<bool> onNearestModeChanged;
  final VoidCallback onRequestLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<bool>(
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              label: Text('كل الحواجز'),
              icon: Icon(Icons.list_alt_rounded, size: 18),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text('أقرب الحواجز'),
              icon: Icon(Icons.near_me_rounded, size: 18),
            ),
          ],
          selected: <bool>{nearestMode},
          onSelectionChanged: (Set<bool> selected) {
            final bool next = selected.single;
            onNearestModeChanged(next);
            if (next) {
              onRequestLocation();
            }
          },
        ),
      ],
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
                color: ReferenceCheckpointTileTheme.primaryBlue
                    .withValues(alpha: 0.2),
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
