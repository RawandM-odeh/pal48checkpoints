import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../utils/ar_relative_time.dart';
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

class _CheckpointMapScreenState extends State<CheckpointMapScreen> {
  final MapController _mapController = MapController();
  String _markerSignature = '';
  String _lastFitSignature = '';

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
    withCoords.sort(
      (Checkpoint a, Checkpoint b) => a.id.compareTo(b.id),
    );
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

  void _scheduleFitCamera(List<Checkpoint> items) {
    final List<Checkpoint> pts =
        items.where((Checkpoint c) => c.hasCoordinates).toList(growable: false);
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
          _mapController.move(
            LatLng(c.latitude!, c.longitude!),
            12,
          );
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
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(56),
          ),
        );
      } catch (_) {
        // تجاهل إذا كانت الحدود غير صالحة لسبب ما
      }
    });
  }

  void _showCityFilterSheet(
    BuildContext context,
    Map<String, String> catalog,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C2F38),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        final List<MapEntry<String, String>> entries =
            catalog.entries.toList(growable: false)
              ..sort(
                (MapEntry<String, String> a, MapEntry<String, String> b) =>
                    a.value.compareTo(b.value),
              );
        final double maxH = MediaQuery.sizeOf(bc).height * 0.62;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder:
                (BuildContext context, void Function(void Function()) setModal) {
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
                              color: Colors.white,
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
                            final bool on = _selectedCityKeys.contains(e.key);
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
                              activeColor: const Color(0xFF2196F3),
                              title: Text(
                                e.value,
                                style: const TextStyle(color: Colors.white),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
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

  Future<void> _goToMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      _mapController.move(LatLng(pos.latitude, pos.longitude), 13);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تحديد موقعك')),
        );
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _showCheckpointSheet(BuildContext context, Checkpoint c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C2F38),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  c.name.isEmpty ? 'بدون اسم' : c.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(bc).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (c.location.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    c.location.trim(),
                    textAlign: TextAlign.center,
                    style: Theme.of(bc).textTheme.bodyMedium?.copyWith(
                          color: Colors.white60,
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

    final List<Marker> markers = filtered
        .map(
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
        )
        .toList(growable: false);

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
              color: const Color(0xE61A1C23),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showCityFilterSheet(context, catalog),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.filter_alt_outlined,
                        color: Color(0xFF2196F3),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'فلتر المدن',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
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
                          color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_selectedCityKeys.length}/${catalog.length}',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: const Color(0xFF90CAF9),
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
          child: Material(
            color: const Color(0xFF2C2F38),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: 'موقعي',
              onPressed: _goToMyLocation,
              icon: const Icon(Icons.my_location, color: Color(0xFF2196F3)),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 96,
          child: Material(
            color: const Color(0xFF2C2F38),
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'الدبوس',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                  const SizedBox(height: 6),
                  _SplitLegendPreview(),
                  const SizedBox(height: 4),
                  Text(
                    'النصف الأيسر = دخول · الأيمن = خروج',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white38,
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
              color: const Color(0xE61A1C23),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'لا توجد إحداثيات على الحواجز بعد — أضف latitude/longitude في Firestore.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade200,
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
              color: const Color(0xE61A1C23),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'لم يُحدَّد عرض أي مدينة — اضغط «فلتر المدن» واختر المدن التي تريدها على الخريطة.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.lightBlue.shade100,
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
            border: Border.all(color: Colors.white24),
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
                color: Colors.white38,
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
                color: Colors.white60,
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
                border: Border.all(color: Colors.white24),
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
                          color: Colors.white54,
                        ),
                  ),
                  Text(
                    'اضغط لتغيير الحالة',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF2196F3),
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
