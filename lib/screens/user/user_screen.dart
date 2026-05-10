import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/guest_browse_provider.dart';
import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/saved_checkpoints_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_location_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/city_display_ar.dart';
import '../../utils/guest_session.dart';
import 'checkpoint_list.dart';
import 'checkpoint_map_screen.dart';
import 'checkpoint_update_picker_screen.dart';
import 'saved_checkpoints_screen.dart';
import 'favorites_screen.dart';

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

class _UserScreenState extends State<UserScreen> with WidgetsBindingObserver {
  int _bottomNavIndex = 0;
  int _mainTab = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _compactCards = false;

  /// عرض «أقرب الحواجز» يعتمد على GPS؛ الافتراضي عرض كل الحواجز حسب المدينة.
  bool _nearestListMode = false;
  String? _cityFilter;

  /// Anchor for the city popup menu ([showMenu]) near the city chip.
  final GlobalKey _cityMenuAnchorKey = GlobalKey();

  /// شريط التنقل بخمس عُقد؛ [2] = «تحديث حالة حاجز» وليست شاشة.
  static const int _kRailShareIndex = 2;

  int _screenToRailIndex(int screenIndex) {
    if (screenIndex < 2) {
      return screenIndex;
    }
    return screenIndex + 1;
  }

  /// `null` يعني ضغط على زر تحديث حالة الحاجز.
  int? _screenIndexFromRail(int railIndex) {
    if (railIndex == _kRailShareIndex) {
      return null;
    }
    if (railIndex < 2) {
      return railIndex;
    }
    return railIndex - 1;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted && _nearestListMode) {
      context.read<UserLocationProvider>().resolve();
    }
  }

  ThemeData _lightUserTheme(BuildContext base) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _PalUi.primaryBlue,
      brightness: Brightness.light,
      surface: AppColors.cardLight,
    );
    final TextTheme baseText = Theme.of(base).textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _PalUi.pageBg,
      colorScheme: scheme.copyWith(
        surface: AppColors.cardLight,
        onSurface: AppColors.textPrimaryLight,
        primary: _PalUi.primaryBlue,
        onPrimary: Colors.white,
        outline: AppColors.borderSubtleLight,
      ),
      textTheme: baseText.copyWith(
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
          color: AppColors.textPrimaryLight,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLight,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: AppColors.textPrimaryLight,
          height: 1.4,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          height: 1.4,
          color: AppColors.textPrimaryLight,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppLayout.cardElevation,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusLg),
          side: const BorderSide(color: AppColors.borderSubtleLight),
        ),
        color: AppColors.cardLight,
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _PalUi.primaryBlue.withValues(alpha: 0.22),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          if (s.contains(WidgetState.selected)) {
            return IconThemeData(color: _PalUi.primaryBlue, size: 26);
          }
          return IconThemeData(color: AppColors.textMutedLight, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          final TextStyle style =
              Theme.of(base).textTheme.labelMedium ?? const TextStyle();
          if (s.contains(WidgetState.selected)) {
            return style.copyWith(
              color: _PalUi.primaryBlue,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              height: 1.2,
              letterSpacing: -0.1,
            );
          }
          return style.copyWith(
            color: AppColors.textMutedLight,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 1.22,
            letterSpacing: -0.05,
          );
        }),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        ),
      ),
    );
  }

  Future<void> _openFavoritesIfAllowed() async {
    if (!await ensureLoggedInForFavorites(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()));
  }

  Future<void> _openSavedCheckpointsScreen() async {
    if (!canUserMakeCheckpointWrites) {
      await showSavedLoginRequiredDialog(context);
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SavedCheckpointsScreen(),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  /// Compact popup menu next to the city chip (not a full-screen bottom sheet).
  Future<void> _openCityMenu(List<String> cities) async {
    final BuildContext? anchorContext = _cityMenuAnchorKey.currentContext;
    if (anchorContext == null) {
      return;
    }
    final RenderBox button = anchorContext.findRenderObject()! as RenderBox;
    final OverlayState overlayState = Overlay.of(anchorContext);
    final RenderBox overlay =
        overlayState.context.findRenderObject()! as RenderBox;

    final Offset origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size size = button.size;
    final Rect anchorRect = origin & size;
    final RelativeRect position = RelativeRect.fromRect(
      anchorRect,
      Offset.zero & overlay.size,
    );

    final double screenH = MediaQuery.sizeOf(context).height;
    final String? picked = await showMenu<String>(
      context: context,
      position: position,
      color: AppColors.cardLight,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderSubtleLight),
      ),
      constraints: BoxConstraints(
        minWidth: math.min(
          math.max(anchorRect.width, 196),
          overlay.size.width - 24,
        ),
        maxWidth: overlay.size.width - 24,
        maxHeight: math.min(screenH * 0.42, 280),
      ),
      clipBehavior: Clip.antiAlias,
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: '', // all cities
          padding: EdgeInsets.zero,
          child: _CityMenuPopupRow(
            label: 'كل المدن',
            selected: _cityFilter == null,
          ),
        ),
        ...cities.map(
          (String c) => PopupMenuItem<String>(
            value: c,
            padding: EdgeInsets.zero,
            child: _CityMenuPopupRow(
              label: cityDisplayNameAr(c),
              selected: _cityFilter == c,
            ),
          ),
        ),
      ],
    );

    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _cityFilter = picked.isEmpty ? null : picked;
    });
  }

  Widget _buildHomeBody(BuildContext context) {
    final CheckpointProvider cp = context.watch<CheckpointProvider>();
    final SavedCheckpointsProvider saved =
        context.watch<SavedCheckpointsProvider>();
    final Set<String> citySet = <String>{};
    for (final Checkpoint item in cp.items) {
      final String loc = item.location.trim();
      if (loc.isNotEmpty) {
        citySet.add(loc);
      }
    }
    final List<String> cities = citySet.toList()
      ..sort(
        (String a, String b) =>
            cityDisplayNameAr(a).compareTo(cityDisplayNameAr(b)),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _BlueHeader(
          savedHasBookmarks: saved.ids.isNotEmpty,
          onSavedPressed: () => unawaited(_openSavedCheckpointsScreen()),
          onFavoritesPressed: () => unawaited(_openFavoritesIfAllowed()),
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
          padding: const EdgeInsets.fromLTRB(
            AppLayout.pagePaddingH,
            AppLayout.spaceMd,
            AppLayout.pagePaddingH,
            0,
          ),
          child: Material(
            color: AppColors.cardLight,
            elevation: 2,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppLayout.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppLayout.spaceSm),
              child: _MainSegmentSwitch(
                selectedIndex: _mainTab,
                onChanged: (int i) => setState(() => _mainTab = i),
              ),
            ),
          ),
        ),
        if (_mainTab == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppLayout.pagePaddingH,
              AppLayout.spaceMd,
              AppLayout.pagePaddingH,
              AppLayout.spaceSm,
            ),
            child: Material(
              color: AppColors.cardLight,
              elevation: 2,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppLayout.radiusLg),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppLayout.spaceMd,
                  end: AppLayout.spaceMd,
                  top: 10,
                  bottom: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      flex: 10,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (_, TextEditingValue v, _) {
                          return Material(
                            color: AppColors.shellBackground,
                            elevation: 0,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppLayout.radiusMd + 6,
                              ),
                              side: BorderSide(
                                color: AppColors.borderSubtleLight.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.search,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 14.5),
                              onChanged: (String s) =>
                                  setState(() => _searchQuery = s),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'بحث بالاسم أو الحالة…',
                                hintStyle: TextStyle(
                                  color: AppColors.textMutedLight.withValues(
                                    alpha: 0.92,
                                  ),
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: AppColors.textMutedLight,
                                  size: 21,
                                ),
                                suffixIcon: v.text.isNotEmpty
                                    ? IconButton(
                                        tooltip: 'مسح',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: _clearSearch,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: AppColors.textMutedLight,
                                          size: 20,
                                        ),
                                      )
                                    : null,
                                contentPadding:
                                    const EdgeInsetsDirectional.only(
                                      start: 4,
                                      end: 4,
                                      top: 10,
                                      bottom: 10,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppLayout.spaceSm),
                    Expanded(
                      flex: 14,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _FilterChipsRow(
                          cityChipKey: _cityMenuAnchorKey,
                          cityLabel: _cityFilter == null
                              ? 'اختر مدينة'
                              : cityDisplayNameAr(_cityFilter!),
                          closestOn: _nearestListMode,
                          compactOn: _compactCards,
                          onCityTap: () => unawaited(_openCityMenu(cities)),
                          onClosestTap: () {
                            final bool next = !_nearestListMode;
                            setState(() => _nearestListMode = next);
                            final UserLocationProvider loc = context
                                .read<UserLocationProvider>();
                            loc.setNearestModeActive(next);
                            if (next && mounted) {
                              loc.resolve();
                            }
                          },
                          onCompactTap: () =>
                              setState(() => _compactCards = !_compactCards),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: _mainTab == 0
              ? CheckpointList(
                  nearestMode: _nearestListMode,
                  onNearestModeChanged: (bool enabled) {
                    setState(() => _nearestListMode = enabled);
                    final UserLocationProvider loc = context
                        .read<UserLocationProvider>();
                    loc.setNearestModeActive(enabled);
                    if (enabled && mounted) {
                      loc.resolve();
                    }
                  },
                  searchQuery: _searchQuery,
                  compactMode: _compactCards,
                  cityFilter: _cityFilter,
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
    final NotificationProvider inbox = context.watch<NotificationProvider>();

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
                  'خريطة',
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
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Material(
                elevation: 14,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                surfaceTintColor: Colors.transparent,
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(AppLayout.radiusLg + 4),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppLayout.radiusLg + 4),
                    border: Border.all(
                      color: AppColors.borderSubtleLight.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    indicatorColor: _PalUi.primaryBlue.withValues(alpha: 0.24),
                    selectedIndex: _screenToRailIndex(_bottomNavIndex),
                    height: 78,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    animationDuration: const Duration(milliseconds: 280),
                    onDestinationSelected: (int railIndex) {
                      final int? nextScreen = _screenIndexFromRail(railIndex);
                      if (nextScreen == null) {
                        unawaited(
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const CheckpointUpdatePickerScreen(),
                            ),
                          ),
                        );
                        return;
                      }
                      final int prev = _bottomNavIndex;
                      setState(() => _bottomNavIndex = nextScreen);
                      if (nextScreen == 0 &&
                          prev != 0 &&
                          mounted &&
                          _nearestListMode) {
                        context.read<UserLocationProvider>().resolve();
                      }
                    },
                    destinations: <NavigationDestination>[
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined, size: 24),
                        selectedIcon: const Icon(
                          Icons.home_rounded,
                          size: 26,
                          color: _PalUi.primaryBlue,
                        ),
                        label: 'الرئيسية',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.map_outlined, size: 24),
                        selectedIcon: const Icon(
                          Icons.map_rounded,
                          size: 26,
                          color: _PalUi.primaryBlue,
                        ),
                        label: 'خريطة',
                      ),
                      NavigationDestination(
                        icon: _ShareNavIcon(selected: false),
                        selectedIcon: _ShareNavIcon(selected: true),
                        label: 'تحديث حالة حاجز',
                      ),
                      NavigationDestination(
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 24,
                        ),
                        selectedIcon: const Icon(
                          Icons.notifications_rounded,
                          size: 26,
                          color: _PalUi.primaryBlue,
                        ),
                        label: 'الإشعارات',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.menu_rounded, size: 24),
                        selectedIcon: const Icon(
                          Icons.menu_open_rounded,
                          size: 26,
                          color: _PalUi.primaryBlue,
                        ),
                        label: 'الإعدادات',
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.textMutedLight),
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
  const _BlueHeader({
    required this.onMenuPressed,
    required this.onFavoritesPressed,
    required this.savedHasBookmarks,
    required this.onSavedPressed,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onFavoritesPressed;

  /// أيقونة «المثبتة» البيضاء فقط بجانب المفضلة.
  final bool savedHasBookmarks;
  final VoidCallback onSavedPressed;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _PalUi.primaryBlue,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppLayout.radiusXl),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _PalUi.primaryBlue.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                IconButton(
                  tooltip: 'المفضلة',
                  onPressed: onFavoritesPressed,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'المثبتة',
                  onPressed: onSavedPressed,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    savedHasBookmarks
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 26,
                  ),
                ),
              ],
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
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
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
      borderRadius: BorderRadius.circular(AppLayout.radiusSm + 1),
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
                color: selected ? _PalUi.primaryBlue : AppColors.textMutedLight,
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

/// Filter chips only (no scroll); parent supplies [SingleChildScrollView].
class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.cityChipKey,
    required this.cityLabel,
    required this.closestOn,
    required this.compactOn,
    required this.onCityTap,
    required this.onClosestTap,
    required this.onCompactTap,
  });

  final Key cityChipKey;
  final String cityLabel;
  final bool closestOn;
  final bool compactOn;
  final VoidCallback onCityTap;
  final VoidCallback onClosestTap;
  final VoidCallback onCompactTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _FilterChipButton(
          key: cityChipKey,
          icon: Icons.keyboard_arrow_down_rounded,
          label: cityLabel,
          selected: cityLabel != 'اختر مدينة',
          onTap: onCityTap,
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
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    super.key,
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? _PalUi.primaryBlue.withValues(alpha: 0.15)
                : AppColors.shellBackground,
            border: Border.all(
              width: 1,
              color: selected
                  ? _PalUi.primaryBlue.withValues(alpha: 0.38)
                  : AppColors.borderSubtleLight,
            ),
            boxShadow: selected
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? _PalUi.primaryBlue
                      : AppColors.textMutedLight,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.textPrimaryLight
                        : AppColors.textMutedLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row inside [showMenu] for city / «كل المدن».
class _CityMenuPopupRow extends StatelessWidget {
  const _CityMenuPopupRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsetsDirectional.only(
        start: 12,
        end: 12,
        top: 11,
        bottom: 11,
      ),
      decoration: BoxDecoration(
        color: selected
            ? _PalUi.primaryBlue.withValues(alpha: 0.12)
            : Colors.transparent,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: selected
                      ? _PalUi.primaryBlue
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 10),
              Icon(Icons.check_rounded, size: 20, color: _PalUi.primaryBlue),
            ],
          ],
        ),
      ),
    );
  }
}

/// أيقونة زر «تحديث حالة حاجز» داخل [NavigationBar] (بين الخريطة والإشعارات).
class _ShareNavIcon extends StatelessWidget {
  const _ShareNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'تحديث أو مشاركة حالة نقطة تفتيش',
      button: true,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? _PalUi.primaryBlue.withValues(alpha: 0.22)
              : _PalUi.primaryBlue.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: _PalUi.primaryBlue.withValues(alpha: selected ? 0.45 : 0.3),
          ),
        ),
        child: Icon(
          Icons.edit_note_rounded,
          size: 23,
          color: _PalUi.primaryBlue,
        ),
      ),
    );
  }
}
