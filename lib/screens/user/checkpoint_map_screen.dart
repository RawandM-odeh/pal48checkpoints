import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/saved_checkpoints_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/ar_relative_time.dart';
import '../../utils/city_display_ar.dart';
import '../../utils/geo_distance.dart';
import '../../utils/request_device_position.dart';
import '../../utils/guest_session.dart';
import '../widgets/checkpoint_card.dart';
import '../widgets/split_checkpoint_pin.dart';

/// OSM tiles — راجع سياسة الاستخدام للإنتاج؛ للتطوير يكفي الخادم الافتراضي.
abstract final class _OsmTiles {
  static const String urlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}

abstract final class _MapSeed {
  static final LatLng palestine = LatLng(31.9522, 35.2332);
  static const double initialZoom = 8.6;
}

/// خريطة OpenStreetMap عبر [flutter_map] — بدون Google Maps API أو فوترة Google.
class CheckpointMapScreen extends StatefulWidget {
  const CheckpointMapScreen({super.key});

  @override
  State<CheckpointMapScreen> createState() => _CheckpointMapScreenState();
}

abstract final class _NearbyMapUi {
  static const int sheetMaxRows = 20;
}

class _NearRowCp {
  const _NearRowCp({required this.checkpoint, required this.distanceKm});
  final Checkpoint checkpoint;
  final double distanceKm;
}

class _CheckpointMapScreenState extends State<CheckpointMapScreen> {
  final MapController _mapController = MapController();
  String _markerSignature = '';
  String _lastFitSignature = '';

  LatLng? _userMapPoint;

  bool _resolvingLocation = false;

  /// مفتاح تطبيع للمدينة من حقل [Checkpoint.location] — للتجميع وتجنّب التكرار الكاسِر.
  static String _cityKey(Checkpoint c) {
    final String s = c.location.trim();
    if (s.isEmpty) {
      return '__NONE__';
    }
    return s.toLowerCase();
  }

  /// عناوين المدن المعروضة في الفلتر (أول نص غير فارغ لكل مفتاح).
  static Map<String, String> _cityCatalog(List<Checkpoint> withCoords) {
    final Map<String, String> catalog = <String, String>{};
    for (final Checkpoint c in withCoords) {
      final String k = _cityKey(c);
      catalog.putIfAbsent(
        k,
        () => k == '__NONE__' ? 'بدون مدينة' : c.location.trim(),
      );
    }
    return catalog;
  }

  static String _signature(List<Checkpoint> items) {
    final List<Checkpoint> withCoords = items
        .where((Checkpoint c) => c.hasCoordinates)
        .toList(growable: false);
    withCoords.sort((Checkpoint a, Checkpoint b) => a.id.compareTo(b.id));
    return withCoords
        .map(
          (Checkpoint c) =>
              '${c.id}:${c.entranceStatus}:${c.exitStatus}:${c.latitude}:${c.longitude}',
        )
        .join('|');
  }

  /// مدن يختارها المستخدم؛ لا تُعرض علامات إلا لهذه المفاتيح (تقليل الحمل على الخريطة).
  final Set<String> _selectedCityKeys = <String>{};

  static String _selectionToken(Set<String> keys) {
    final List<String> sorted = keys.toList(growable: false)..sort();
    return sorted.join(',');
  }

  /// المرشّح المعروض على الخريطة؛ إذا لم يُختر أي مدينة نستخدم كل الحواجز ذات الإحداثيات (للمسافة).
  List<Checkpoint> _nearbyCandidates(List<Checkpoint> withCoords) {
    final List<Checkpoint> fromFilter =
        withCoords.where((Checkpoint c) => _selectedCityKeys.contains(_cityKey(c))).toList(growable: false);
    return fromFilter.isEmpty
        ? List<Checkpoint>.from(withCoords)
        : fromFilter;
  }

  String _formatKmAr(double km) {
    const double epsilon = 0.05;
    if (km < epsilon) {
      return 'بالقرب جدًا';
    }
    if (km < 10) {
      return '${km.toStringAsFixed(1)} كم';
    }
    return '${km.round()} كم';
  }

  void _presentLocationFailure(BuildContext scaffoldContext, DeviceLocationFailureKind kind) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(scaffoldContext);
    final SnackBarAction? action = switch (kind) {
      DeviceLocationFailureKind.serviceDisabled => SnackBarAction(
          label: 'إعدادات الموقع',
          onPressed: () => unawaited(Geolocator.openLocationSettings()),
        ),
      DeviceLocationFailureKind.permissionDeniedForever => SnackBarAction(
          label: 'إعدادات التطبيق',
          onPressed: () => unawaited(Geolocator.openAppSettings()),
        ),
      DeviceLocationFailureKind.permissionDenied => SnackBarAction(
          label: 'إعادة الطلب',
          onPressed: () {
            _goToMyLocation();
          },
        ),
      DeviceLocationFailureKind.unavailable => null,
    };
    messenger.showSnackBar(
      SnackBar(
        content: Text(kind.descriptionAr),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  void _showNearbyCheckpointsSheet(
    BuildContext hostContext,
    LatLng user,
    List<Checkpoint> source,
  ) {
    if (source.isEmpty) {
      ScaffoldMessenger.of(hostContext).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'لا توجد حواجز بإحداثيات لمسافتها منك أو لم تُحمَّل بعد.',
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    final List<_NearRowCp> ranked = source
        .map(
          (Checkpoint c) => _NearRowCp(
            checkpoint: c,
            distanceKm: haversineKm(
              user.latitude,
              user.longitude,
              c.latitude!,
              c.longitude!,
            ),
          ),
        )
        .toList(growable: false)
      ..sort((_NearRowCp a, _NearRowCp b) => a.distanceKm.compareTo(b.distanceKm));

    final List<_NearRowCp> trimmed = ranked
        .take(_NearbyMapUi.sheetMaxRows)
        .toList(growable: false);

    showModalBottomSheet<void>(
      context: hostContext,
      backgroundColor: AppColors.cardLight,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.paddingOf(bc).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'أقرب الحواجز من موقعك',
                  textAlign: TextAlign.center,
                  style: Theme.of(bc).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(bc).height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: trimmed.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppColors.borderSubtleLight.withValues(alpha: 0.6)),
                    itemBuilder: (BuildContext _, int i) {
                      final _NearRowCp row = trimmed[i];
                      final Checkpoint c = row.checkpoint;
                      final String subtitle = _formatKmAr(row.distanceKm);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: SizedBox(
                          width: 32,
                          child: Align(
                            child: SplitCheckpointPin(
                              entranceStatus: c.entranceStatus,
                              exitStatus: c.exitStatus,
                              size: 24,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name.isEmpty ? 'بدون اسم' : c.name,
                          style: const TextStyle(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(text: subtitle, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
                              if (c.location.trim().isNotEmpty)
                                TextSpan(
                                  text: ' · ${cityDisplayNameAr(c.location.trim())}',
                                  style: Theme.of(bc).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textMutedLight,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        onTap: () {
                          Navigator.of(bc).pop();
                          _mapController.move(LatLng(c.latitude!, c.longitude!), 14);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              unawaited(_showCheckpointSheet(hostContext, c));
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _goToMyLocation() async {
    if (_resolvingLocation) {
      return;
    }
    setState(() => _resolvingLocation = true);
    try {
      final DeviceLocationResult result = await requestDeviceLocation();
      if (!mounted) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      if (!result.isSuccess) {
        _presentLocationFailure(context, result.failureKind!);
        return;
      }

      final Position pos = result.position!;
      final LatLng ll = LatLng(pos.latitude, pos.longitude);

      setState(() => _userMapPoint = ll);
      _mapController.move(ll, 14);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('تم تحديد موقعك على الخريطة.'),
          action: SnackBarAction(
            label: 'الأقرب',
            onPressed: () {
              final CheckpointProvider cp = context.read<CheckpointProvider>();
              final List<Checkpoint> coords = cp.items
                  .where((Checkpoint c) => c.hasCoordinates)
                  .toList(growable: false);
              _showNearbyCheckpointsSheet(context, ll, _nearbyCandidates(coords));
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingLocation = false);
      }
    }
  }

  void _onNearbyFabPressed(BuildContext scaffoldContext, List<Checkpoint> withCoords) {
    final LatLng? u = _userMapPoint;
    if (u == null) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'اضغط «موقعي» أولًا ليقرأ التطبيق GPS ويحدِّد مكانك.',
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }
    _showNearbyCheckpointsSheet(scaffoldContext, u, _nearbyCandidates(withCoords));
  }

  void _scheduleFitCamera(List<Checkpoint> items) {
    final List<Checkpoint> pts = items
        .where((Checkpoint c) => c.hasCoordinates)
        .toList(growable: false);
    final String sig = _signature(items);
    if (pts.isEmpty) {
      if (sig != _lastFitSignature) {
        _lastFitSignature = sig;
      }
      return;
    }
    if (sig == _lastFitSignature) {
      return;
    }
    _lastFitSignature = sig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || pts.isEmpty) {
        return;
      }
      try {
        if (pts.length == 1) {
          final Checkpoint c = pts.first;
          _mapController.move(LatLng(c.latitude!, c.longitude!), 12);
          return;
        }
        double minLat = pts.first.latitude!;
        double maxLat = minLat;
        double minLng = pts.first.longitude!;
        double maxLng = minLng;
        for (final Checkpoint c in pts) {
          final double lat = c.latitude!;
          final double lng = c.longitude!;
          if (lat < minLat) {
            minLat = lat;
          }
          if (lat > maxLat) {
            maxLat = lat;
          }
          if (lng < minLng) {
            minLng = lng;
          }
          if (lng > maxLng) {
            maxLng = lng;
          }
        }
        final LatLngBounds bounds = LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        );
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
        );
      } catch (_) {
        // تجاهل إذا كانت الحدود غير صالحة لسبب ما
      }
    });
  }

  void _showCityFilterSheet(BuildContext context, Map<String, String> catalog) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardLight,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        final List<MapEntry<String, String>> entries =
            catalog.entries.toList(growable: false)..sort(
              (MapEntry<String, String> a, MapEntry<String, String> b) =>
                  cityDisplayNameAr(
                    a.value,
                  ).compareTo(cityDisplayNameAr(b.value)),
            );
        final double maxH = MediaQuery.sizeOf(bc).height * 0.62;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder:
                (
                  BuildContext context,
                  void Function(void Function()) setModal,
                ) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      16 + MediaQuery.paddingOf(bc).bottom,
                    ),
                    child: SizedBox(
                      height: maxH,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'اختر المدن المعروضة على الخريطة',
                            textAlign: TextAlign.center,
                            style: Theme.of(bc).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedCityKeys
                                      ..clear()
                                      ..addAll(catalog.keys);
                                  });
                                  setModal(() {});
                                },
                                child: const Text('تحديد الكل'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(_selectedCityKeys.clear);
                                  setModal(() {});
                                },
                                child: const Text('مسح'),
                              ),
                            ],
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: entries.length,
                              itemBuilder: (BuildContext _, int i) {
                                final MapEntry<String, String> e = entries[i];
                                final bool on = _selectedCityKeys.contains(
                                  e.key,
                                );
                                return CheckboxListTile(
                                  value: on,
                                  onChanged: (bool? v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedCityKeys.add(e.key);
                                      } else {
                                        _selectedCityKeys.remove(e.key);
                                      }
                                    });
                                    setModal(() {});
                                  },
                                  activeColor: AppColors.brandTeal,
                                  title: Text(
                                    e.key == '__NONE__'
                                        ? e.value
                                        : cityDisplayNameAr(e.value),
                                    style: const TextStyle(
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _toggleMapCheckpointSaved(
    BuildContext hostContext,
    SavedCheckpointsProvider sv,
    Checkpoint checkpoint,
  ) async {
    if (!await ensureLoggedInForSaved(hostContext)) {
      return;
    }
    if (!hostContext.mounted) {
      return;
    }
    sv.toggle(checkpoint.id);
  }

  Future<void> _showCheckpointSheet(BuildContext context, Checkpoint c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardLight,
      showDragHandle: true,
      builder: (BuildContext bc) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              16 + MediaQuery.paddingOf(bc).bottom,
            ),
            child: Consumer<SavedCheckpointsProvider>(
              builder: (
                BuildContext _,
                SavedCheckpointsProvider sv,
                Widget? child,
              ) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: TextDirection.rtl,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'مثبتة',
                          onPressed: () => unawaited(
                            _toggleMapCheckpointSaved(context, sv, c),
                          ),
                          icon: Icon(
                            sv.isSaved(c.id)
                                ? Icons.bookmark
                                : Icons.bookmark_border_rounded,
                            color: sv.isSaved(c.id)
                                ? AppColors.brandTeal
                                : AppColors.textMutedLight,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            c.name.isEmpty ? 'بدون اسم' : c.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(bc).textTheme.titleLarge?.copyWith(
                                  color: AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 48, height: 48),
                      ],
                    ),
                    if (c.location.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        cityDisplayNameAr(c.location),
                        textAlign: TextAlign.center,
                        style: Theme.of(bc).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMutedLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SheetDirectionRow(
                      label: 'للداخل',
                      status: c.entranceStatus,
                      updated: c.entranceUpdatedAt,
                      onTap: () async {
                        Navigator.of(bc).pop();
                        await showCheckpointStatusSheet(
                          context: context,
                          checkpoint: c,
                          direction: 'entrance',
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _SheetDirectionRow(
                      label: 'للخارج',
                      status: c.exitStatus,
                      updated: c.exitUpdatedAt,
                      onTap: () async {
                        Navigator.of(bc).pop();
                        await showCheckpointStatusSheet(
                          context: context,
                          checkpoint: c,
                          direction: 'exit',
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CheckpointProvider cp = context.watch<CheckpointProvider>();
    final List<Checkpoint> withCoords = cp.items
        .where((Checkpoint c) => c.hasCoordinates)
        .toList(growable: false);

    final Map<String, String> catalog = _cityCatalog(withCoords);
    final Set<String> catalogKeys = catalog.keys.toSet();
    final Set<String> staleKeys = _selectedCityKeys.difference(catalogKeys);
    if (staleKeys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedCityKeys.removeAll(staleKeys);
        });
      });
    }

    final List<Checkpoint> filtered = withCoords
        .where((Checkpoint c) => _selectedCityKeys.contains(_cityKey(c)))
        .toList(growable: false);

    final String markerSig =
        '${_signature(filtered)}|${_selectionToken(_selectedCityKeys)}';
    if (markerSig != _markerSignature) {
      _markerSignature = markerSig;
      _scheduleFitCamera(filtered);
    }

    final LatLng? userPoint = _userMapPoint;
    final List<Marker> markers = <Marker>[
      ...filtered.map(
        (Checkpoint c) => Marker(
          point: LatLng(c.latitude!, c.longitude!),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _showCheckpointSheet(context, c),
            child: SplitCheckpointPin(
              entranceStatus: c.entranceStatus,
              exitStatus: c.exitStatus,
              size: 28,
            ),
          ),
        ),
      ),
      if (userPoint != null)
        Marker(
          point: userPoint,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            Icons.navigation_rounded,
            size: 36,
            color: const Color(0xFF1565C0),
            shadows: <Shadow>[
              Shadow(
                color: Colors.white.withValues(alpha: 0.92),
                blurRadius: 8,
              ),
            ],
          ),
        ),
    ];

    final bool hasCoords = withCoords.isNotEmpty;
    final bool needsCityPick = hasCoords && _selectedCityKeys.isEmpty;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _MapSeed.palestine,
            initialZoom: _MapSeed.initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: _OsmTiles.urlTemplate,
              userAgentPackageName: 'com.example.checkpoint_app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        if (catalog.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.96),
              elevation: 2,
              shadowColor: AppColors.brandTeal.withValues(alpha: 0.14),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.borderSubtleLight),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showCityFilterSheet(context, catalog),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.filter_alt_outlined,
                        color: AppColors.brandTeal,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'فلتر المدن',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.textPrimaryLight,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_selectedCityKeys.length}/${catalog.length}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.brandTealDark,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 4,
          child: Text(
            '© OpenStreetMap contributors',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              shadows: <Shadow>[
                Shadow(
                  color: Colors.black.withValues(alpha: 0.85),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Material(
                color: AppColors.cardLight,
                elevation: 2,
                shadowColor: AppColors.brandTeal.withValues(alpha: 0.14),
                surfaceTintColor: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'الحواجز القريبة',
                  onPressed: () => _onNearbyFabPressed(context, withCoords),
                  icon: const Icon(Icons.near_me_rounded, color: AppColors.brandTeal),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: AppColors.cardLight,
                elevation: 3,
                shadowColor: AppColors.brandTeal.withValues(alpha: 0.18),
                surfaceTintColor: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'موقعي',
                  onPressed: _resolvingLocation ? null : _goToMyLocation,
                  icon: _resolvingLocation
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandTealDark,
                          ),
                        )
                      : const Icon(Icons.my_location, color: AppColors.brandTeal),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 96,
          child: Material(
            color: AppColors.cardLight.withValues(alpha: 0.97),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderSubtleLight),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'الدبوس',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textMutedLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _SplitLegendPreview(),
                  const SizedBox(height: 4),
                  Text(
                    'النصف الأيسر = دخول · الأيمن = خروج',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textMutedLight,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!hasCoords && !cp.loading && cp.error == null)
          Positioned(
            left: 16,
            right: 16,
            top: catalog.isNotEmpty ? 68 : 12,
            child: Material(
              color: Colors.white.withValues(alpha: 0.96),
              elevation: 2,
              shadowColor: AppColors.brandTeal.withValues(alpha: 0.12),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.borderSubtleLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'لا توجد إحداثيات على الحواجز بعد — أضف latitude/longitude في Firestore.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (needsCityPick && !cp.loading && cp.error == null)
          Positioned(
            left: 16,
            right: 16,
            top: catalog.isNotEmpty ? 68 : 12,
            child: Material(
              color: Colors.white.withValues(alpha: 0.96),
              elevation: 2,
              shadowColor: AppColors.brandTeal.withValues(alpha: 0.12),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.borderSubtleLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'لم يُحدَّد عرض أي مدينة — اضغط «فلتر المدن» واختر المدن التي تريدها على الخريطة.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplitLegendPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 56,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtleLight),
          ),
          clipBehavior: Clip.antiAlias,
          child: const Row(
            children: <Widget>[
              Expanded(
                child: ColoredBox(
                  color: Color(0xFF2E7D32),
                  child: SizedBox(height: 14),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: Color(0xFFC62828),
                  child: SizedBox(height: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'كل نصف بلون حالة ذلك الاتجاه (سالك، أزمة، مغلق، جيش، مستوطنون)',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textMutedLight,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SheetDirectionRow extends StatelessWidget {
  const _SheetDirectionRow({
    required this.label,
    required this.status,
    required this.updated,
    required this.onTap,
  });

  final String label;
  final String status;
  final DateTime? updated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg}) styl = CheckpointStatus.badgeColors(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textMutedLight,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: styl.bg.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtleLight),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    CheckpointStatus.badgeLabelAr(status),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: styl.fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    arabicRelativeSince(updated),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMutedLight,
                    ),
                  ),
                  Text(
                    'اضغط لتغيير الحالة',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.brandTeal,
                      fontWeight: FontWeight.w700,
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
