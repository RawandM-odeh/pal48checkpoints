import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/nearby_config.dart';
import '../../providers/guest_browse_provider.dart';
import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_location_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import 'checkpoint_list.dart';
import 'checkpoint_map_screen.dart';

/// هيدر تركوزي + هيكل فاتح ناعم.
abstract final class _PalUi {
  static const Color primaryBlue = AppColors.brandTeal;
  static const Color pageBg = AppColors.shellBackground;
  static const Color segmentInactiveBg = AppColors.shellSegmentTrack;
}

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  int _bottomNavIndex = 0;
  int _mainTab = 0;
  String _searchQuery = '';
  bool _compactCards = false;
  bool _pinnedFilter = false;
  /// عرض «أقرب الحواجز» يعتمد على GPS؛ الافتراضي عرض كل الحواجز حسب المدينة.
  bool _nearestListMode = false;
  String? _cityFilter;
  bool _promoVisible = true;

  ThemeData _lightUserTheme(BuildContext base) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _PalUi.primaryBlue,
      brightness: Brightness.light,
      surface: AppColors.cardLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _PalUi.pageBg,
      colorScheme: scheme.copyWith(
        surface: AppColors.cardLight,
        onSurface: AppColors.textPrimaryLight,
        primary: _PalUi.primaryBlue,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardLight,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _PalUi.primaryBlue.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          final TextStyle baseStyle =
              Theme.of(base).textTheme.labelMedium ?? const TextStyle();
          if (s.contains(WidgetState.selected)) {
            return baseStyle.copyWith(
              color: _PalUi.primaryBlue,
              fontWeight: FontWeight.w700,
            );
          }
          return baseStyle.copyWith(color: AppColors.textMutedLight);
        }),
      ),
    );
  }

  Future<void> _openSearchDialog() async {
    final String? q = await showDialog<String>(
      context: context,
      builder: (_) => const _CheckpointSearchDialog(),
    );
    if (q != null && mounted) {
      setState(() => _searchQuery = q);
    }
  }

  void _showCityPicker(List<String> cities) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardLight,
      showDragHandle: true,
      builder: (BuildContext bc) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: <Widget>[
                ListTile(
                  title: const Text('كل المدن'),
                  trailing: _cityFilter == null
                      ? Icon(Icons.check, color: _PalUi.primaryBlue)
                      : null,
                  onTap: () {
                    setState(() => _cityFilter = null);
                    Navigator.pop(bc);
                  },
                ),
                ...cities.map(
                  (String c) => ListTile(
                    title: Text(c),
                    trailing: _cityFilter == c
                        ? Icon(Icons.check, color: _PalUi.primaryBlue)
                        : null,
                    onTap: () {
                      setState(() => _cityFilter = c);
                      Navigator.pop(bc);
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

  Widget _buildHomeBody(BuildContext context) {
    final CheckpointProvider cp = context.watch<CheckpointProvider>();
    final Set<String> citySet = <String>{};
    for (final Checkpoint item in cp.items) {
      final String loc = item.location.trim();
      if (loc.isNotEmpty) {
        citySet.add(loc);
      }
    }
    final List<String> cities = citySet.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _BlueHeader(
          onMenuPressed: () async {
            await showModalBottomSheet<void>(
              context: context,
              backgroundColor: AppColors.cardLight,
              showDragHandle: true,
              builder: (BuildContext bc) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('تسجيل الخروج'),
                          onTap: () async {
                            Navigator.pop(bc);
                            await AuthService().signOut();
                            if (context.mounted) {
                              await context
                                  .read<GuestBrowseProvider>()
                                  .exitGuestBrowse();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _MainSegmentSwitch(
            selectedIndex: _mainTab,
            onChanged: (int i) => setState(() => _mainTab = i),
          ),
        ),
        _FilterStrip(
          cityLabel: _cityFilter ?? 'اختر مدينة',
          pinnedOn: _pinnedFilter,
          closestOn: _nearestListMode,
          compactOn: _compactCards,
          onCityTap: () => _showCityPicker(cities),
          onPinnedTap: () {
            setState(() => _pinnedFilter = !_pinnedFilter);
            if (_pinnedFilter && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('المثبتة: قريباً')),
              );
            }
          },
          onClosestTap: () {
            setState(() {
              _nearestListMode = !_nearestListMode;
            });
            if (_nearestListMode && mounted) {
              context.read<UserLocationProvider>().resolve();
            }
          },
          onCompactTap: () =>
              setState(() => _compactCards = !_compactCards),
        ),
        Expanded(
          child: _mainTab == 0
              ? CheckpointList(
                  nearbyRadiusKm: NearbyConfig.radiusKm,
                  nearestMode: _nearestListMode,
                  onNearestModeChanged: (bool enabled) {
                    setState(() => _nearestListMode = enabled);
                    if (enabled && mounted) {
                      context.read<UserLocationProvider>().resolve();
                    }
                  },
                  searchQuery: _searchQuery,
                  compactMode: _compactCards,
                  cityFilter: _cityFilter,
                  promoVisible: _promoVisible,
                  onDismissPromo: () => setState(() => _promoVisible = false),
                  onActivatePromo: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تفعيل الإشعارات من إعدادات الجهاز'),
                      ),
                    );
                  },
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'محطات الوقود — قريباً',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textMutedLight,
                          ),
                    ),
                  ),
                ),
        ),
        _ShareUpdatesBar(
          onShareTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('مشاركة تحديث — قريباً')),
            );
          },
          onSearchTap: _openSearchDialog,
        ),
      ],
    );
  }

  Widget _buildSecondaryPane(String title, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 12,
            16,
            8,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final NotificationProvider inbox =
        context.watch<NotificationProvider>();

    return Theme(
      data: _lightUserTheme(context),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _PalUi.pageBg,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_bottomNavIndex) {
              0 => KeyedSubtree(
                  key: const ValueKey<String>('home'),
                  child: _buildHomeBody(context),
                ),
              1 => KeyedSubtree(
                  key: const ValueKey<String>('plan'),
                  child: _buildSecondaryPane(
                    'تخطيط',
                    const CheckpointMapScreen(),
                  ),
                ),
              2 => KeyedSubtree(
                  key: const ValueKey<String>('notif'),
                  child: _buildSecondaryPane(
                    'الإشعارات',
                    _NotificationsBody(inbox: inbox),
                  ),
                ),
              _ => KeyedSubtree(
                  key: const ValueKey<String>('settings'),
                  child: _buildSecondaryPane(
                    'الإعدادات',
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('مسح سجل المعاينة'),
                          subtitle: Text(
                            inbox.entries.isEmpty
                                ? 'لا توجد عناصر'
                                : '${inbox.entries.length} سطر',
                          ),
                          onTap: inbox.entries.isEmpty
                              ? null
                              : () {
                                  context.read<NotificationProvider>().clear();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم المسح')),
                                  );
                                },
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('تسجيل الخروج'),
                          onTap: () async {
                            await AuthService().signOut();
                            if (context.mounted) {
                              await context
                                  .read<GuestBrowseProvider>()
                                  .exitGuestBrowse();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            },
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _bottomNavIndex,
            height: 72,
            onDestinationSelected: (int i) =>
                setState(() => _bottomNavIndex = i),
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon:
                    const Icon(Icons.home, color: _PalUi.primaryBlue),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon:
                    const Icon(Icons.map_rounded, color: _PalUi.primaryBlue),
                label: 'تخطيط',
              ),
              NavigationDestination(
                icon: const Icon(Icons.notifications_none_rounded),
                selectedIcon: const Icon(Icons.notifications_rounded,
                    color: _PalUi.primaryBlue),
                label: 'الإشعارات',
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_rounded),
                selectedIcon: const Icon(Icons.menu_open_rounded,
                    color: _PalUi.primaryBlue),
                label: 'الإعدادات',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody({required this.inbox});

  final NotificationProvider inbox;

  @override
  Widget build(BuildContext context) {
    if (inbox.entries.isEmpty) {
      return Center(
        child: Text(
          'لا توجد إشعارات بعد',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textMutedLight,
              ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: inbox.entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            inbox.entries[i],
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      },
    );
  }
}

class _BlueHeader extends StatelessWidget {
  const _BlueHeader({required this.onMenuPressed});

  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _PalUi.primaryBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(8, top + 8, 8, 18),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'قائمة',
              onPressed: onMenuPressed,
              icon: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ),
          Text(
            'غ وين رايح',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _MainSegmentSwitch extends StatelessWidget {
  const _MainSegmentSwitch({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _PalUi.segmentInactiveBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtleLight),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SegmentTile(
              icon: Icons.travel_explore_outlined,
              label: 'الحواجز والطرق',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentTile(
              icon: Icons.local_gas_station_outlined,
              label: 'محطات الوقود',
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.cardLight : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: selected
                    ? _PalUi.primaryBlue
                    : AppColors.textMutedLight,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.textPrimaryLight
                        : AppColors.textMutedLight,
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

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.cityLabel,
    required this.pinnedOn,
    required this.closestOn,
    required this.compactOn,
    required this.onCityTap,
    required this.onPinnedTap,
    required this.onClosestTap,
    required this.onCompactTap,
  });

  final String cityLabel;
  final bool pinnedOn;
  final bool closestOn;
  final bool compactOn;
  final VoidCallback onCityTap;
  final VoidCallback onPinnedTap;
  final VoidCallback onClosestTap;
  final VoidCallback onCompactTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: <Widget>[
          _FilterChipButton(
            icon: Icons.keyboard_arrow_down_rounded,
            label: cityLabel,
            selected: cityLabel != 'اختر مدينة',
            onTap: onCityTap,
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            icon: Icons.bookmark_outline_rounded,
            label: 'المثبتة',
            selected: pinnedOn,
            onTap: onPinnedTap,
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            icon: Icons.navigation_rounded,
            label: 'الأقرب',
            selected: closestOn,
            onTap: onClosestTap,
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            icon: Icons.view_agenda_outlined,
            label: 'مصغر',
            selected: compactOn,
            onTap: onCompactTap,
          ),
        ],
      ),
    );
  }
}

class _CheckpointSearchDialog extends StatefulWidget {
  const _CheckpointSearchDialog();

  @override
  State<_CheckpointSearchDialog> createState() =>
      _CheckpointSearchDialogState();
}

class _CheckpointSearchDialogState extends State<_CheckpointSearchDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.cardLight,
        title: const Text('بحث عن حاجز'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'اسم الحاجز…',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _PalUi.primaryBlue.withValues(alpha: 0.22)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? _PalUi.primaryBlue.withValues(alpha: 0.35)
                  : AppColors.borderSubtleLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? _PalUi.primaryBlue : AppColors.textMutedLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.textPrimaryLight
                      : AppColors.textMutedLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareUpdatesBar extends StatelessWidget {
  const _ShareUpdatesBar({
    required this.onShareTap,
    required this.onSearchTap,
  });

  final VoidCallback onShareTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'خليك قريب من تحديثاتنا عبر صفحاتنا',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMutedLight,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Material(
                color: AppColors.cardLight,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSearchTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(Icons.search, color: _PalUi.primaryBlue),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _PalUi.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onShareTap,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                  label: const Text(
                    'شاركنا بتحديث',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
