import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../repositories/checkpoint_repository.dart';
import '../user/checkpoint_detail_screen.dart';
import '../../utils/city_display_ar.dart';
import '../widgets/checkpoint_card.dart';

/// مدن فريدة من حقل موقع الحواجز الحالية — للفلترة ولإضافة حاجز جديد.
List<String> _distinctCheckpointCities(List<Checkpoint> items) {
  final Set<String> set = <String>{};
  for (final Checkpoint c in items) {
    final String s = c.location.trim();
    if (s.isNotEmpty) {
      set.add(s);
    }
  }
  final List<String> list = set.toList(growable: false);
  list.sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

class CheckpointsTab extends StatefulWidget {
  const CheckpointsTab({super.key});

  @override
  State<CheckpointsTab> createState() => _CheckpointsTabState();
}

class _CheckpointsTabState extends State<CheckpointsTab> {
  String? _cityFilter;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onBadgeTap(
    BuildContext context,
    Checkpoint checkpoint,
    String direction,
  ) async {
    await showCheckpointStatusSheet(
      context: context,
      checkpoint: checkpoint,
      direction: direction,
      updateSource: CheckpointUpdateSource.admin,
    );
  }

  void _openDetail(BuildContext context, Checkpoint c) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CheckpointDetailScreen(
          initialCheckpoint: c,
          bypassProximityCheck: true,
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const _AddCheckpointDialog();
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context, Checkpoint c) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _EditCheckpointDialog(checkpoint: c);
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Checkpoint c) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف الحاجز؟'),
            content: Text(
              c.name.isEmpty ? 'سيتم حذف هذا الحاجز نهائياً.' : c.name,
              textAlign: TextAlign.right,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      await context.read<CheckpointProvider>().repository.deleteCheckpoint(
        c.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحذف')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  List<Checkpoint> _filtered(List<Checkpoint> items) {
    Iterable<Checkpoint> it = items;
    if (_cityFilter != null) {
      it = it.where((Checkpoint c) => c.location.trim() == _cityFilter);
    }
    final String q = _searchCtrl.text.trim();
    if (q.isNotEmpty) {
      final String ql = q.toLowerCase();
      it = it.where((Checkpoint c) {
        final String haystack =
            '${c.name} ${c.id} ${c.location}'.toLowerCase();
        return haystack.contains(ql);
      });
    }
    return it.toList(growable: false);
  }

  String _emptyFilteredMessage() {
    final bool hasSearch = _searchCtrl.text.trim().isNotEmpty;
    if (hasSearch) {
      return 'لا توجد نتائج للبحث';
    }
    if (_cityFilter != null) {
      return 'لا توجد حواجز لهذه المدينة';
    }
    return 'لا توجد حواجز';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckpointProvider provider = context.watch<CheckpointProvider>();
    final List<Checkpoint> filtered = _filtered(provider.items);
    final List<String> cities = _distinctCheckpointCities(provider.items);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        tooltip: 'إضافة حاجز',
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (BuildContext context) {
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
          if (provider.items.isEmpty) {
            return Center(
              child: Text(
                'لا توجد حواجز',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white54,
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تصفية حسب المدينة',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.location_city_outlined,
                              size: 22,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: _cityFilter,
                                  hint: const Text('كل المدن'),
                                  items: <DropdownMenuItem<String?>>[
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('كل المدن'),
                                    ),
                                    ...cities.map(
                                      (String city) =>
                                          DropdownMenuItem<String?>(
                                        value: city,
                                        child: Text(
                                          city,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (String? v) =>
                                      setState(() => _cityFilter = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        decoration: InputDecoration(
                          labelText: 'بحث',
                          hintText: 'اسم الحاجز، المعرّف، المدينة…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          isDense: true,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white.withValues(alpha: 0.65),
                            size: 22,
                          ),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'مسح',
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: Colors.white.withValues(
                                      alpha: 0.55,
                                    ),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                ),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _emptyFilteredMessage(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              mainAxisExtent:
                                  CheckpointCardStyle.adminCardHeight,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Checkpoint c = filtered[index];
                          return CheckpointCard(
                            checkpoint: c,
                            appearance:
                                CheckpointCardAppearance.darkUserLike,
                            onStatusBadgeTap: (String direction) =>
                                _onBadgeTap(context, c, direction),
                            onCardTap: () => _openDetail(context, c),
                            trailing: const SizedBox(width: 26),
                            footer: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                TextButton.icon(
                                  onPressed: () =>
                                      _showEditDialog(context, c),
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  label: const Text('تعديل'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.primary,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _confirmDelete(context, c),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: theme.colorScheme.error,
                                  ),
                                  label: const Text('حذف'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.error,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddCheckpointDialog extends StatefulWidget {
  const _AddCheckpointDialog();

  @override
  State<_AddCheckpointDialog> createState() => _AddCheckpointDialogState();
}

class _AddCheckpointDialogState extends State<_AddCheckpointDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameArCtrl = TextEditingController();
  final TextEditingController _nameEnCtrl = TextEditingController();

  /// يُستخدم فقط إذا لم تكن هناك مدن مستخرجة بعد من الحواجز الحالية.
  final TextEditingController _cityManualCtrl = TextEditingController();
  final TextEditingController _aliasesCtrl = TextEditingController();
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lngCtrl = TextEditingController();

  String _entranceStatus = CheckpointStatus.open;
  String _exitStatus = CheckpointStatus.open;
  String? _selectedCity;
  bool _saving = false;

  @override
  void dispose() {
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _cityManualCtrl.dispose();
    _aliasesCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  String _aliasesPreview() {
    return CheckpointRepository.mergeAliases(
      nameAr: _nameArCtrl.text,
      nameEn: _nameEnCtrl.text,
      extraRaw: _aliasesCtrl.text,
    ).join('، ');
  }

  double? _parseCoord(String? raw) {
    if (raw == null) {
      return null;
    }
    return double.tryParse(raw.trim().replaceAll(',', '.'));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final double? lat = _parseCoord(_latCtrl.text);
    final double? lng = _parseCoord(_lngCtrl.text);
    if (lat == null || lng == null) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState nav = Navigator.of(context);
    final CheckpointProvider cp = context.read<CheckpointProvider>();
    final CheckpointRepository repo = cp.repository;
    final List<String> cities = _distinctCheckpointCities(cp.items);
    if (cities.isNotEmpty &&
        (_selectedCity == null || !cities.contains(_selectedCity))) {
      messenger.showSnackBar(
        const SnackBar(content: Text('اختر المدينة من القائمة')),
      );
      return;
    }
    final String cityValue = cities.isEmpty
        ? _cityManualCtrl.text.trim()
        : (_selectedCity ?? '').trim();

    setState(() => _saving = true);
    try {
      await repo.addCheckpoint(
        nameAr: _nameArCtrl.text,
        nameEn: _nameEnCtrl.text,
        latitude: lat,
        longitude: lng,
        city: cityValue,
        extraAliases: _aliasesCtrl.text,
        entranceStatus: _entranceStatus,
        exitStatus: _exitStatus,
      );
      if (!mounted) {
        return;
      }
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تمت الإضافة')));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
      messenger.showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckpointProvider cp = context.watch<CheckpointProvider>();
    final List<String> cities = _distinctCheckpointCities(cp.items);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة حاجز'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _nameArCtrl,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'الاسم بالعربي (معرّف الوثيقة)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (String? v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'مطلوب';
                      }
                      if (v.trim().contains('/')) {
                        return 'لا يُسمح بالرمز «/»';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameEnCtrl,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'الاسم بالإنجليزي',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (cities.isEmpty)
                    TextFormField(
                      controller: _cityManualCtrl,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'المدينة',
                        hintText: 'لا توجد مدن بعد — اكتب اسم المدينة يدوياً',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'المدينة',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value:
                              _selectedCity != null &&
                                  cities.contains(_selectedCity)
                              ? _selectedCity
                              : null,
                          hint: const Text(
                            'اختر مدينة',
                            textAlign: TextAlign.right,
                          ),
                          items: cities
                              .map(
                                (String city) => DropdownMenuItem<String>(
                                  value: city,
                                  child: Text(
                                    cityDisplayNameAr(city),
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (String? v) =>
                              setState(() => _selectedCity = v),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _aliasesCtrl,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'أسماء بديلة (فاصلة أو سطر جديد)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيُحفظ كـ aliases: ${_aliasesPreview().isEmpty ? '—' : _aliasesPreview()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _latCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'خط العرض',
                            border: OutlineInputBorder(),
                          ),
                          validator: (String? v) {
                            if (_parseCoord(v) == null) {
                              return 'رقم صالح';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lngCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'خط الطول',
                            border: OutlineInputBorder(),
                          ),
                          validator: (String? v) {
                            if (_parseCoord(v) == null) {
                              return 'رقم صالح';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'حالة الدخول الابتدائية',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _entranceStatus,
                        items: CheckpointStatus.all
                            .map(
                              (String s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(CheckpointStatus.labelAr(s)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _saving
                            ? null
                            : (String? v) {
                                if (v != null) {
                                  setState(() => _entranceStatus = v);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'حالة الخروج الابتدائية',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _exitStatus,
                        items: CheckpointStatus.all
                            .map(
                              (String s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(CheckpointStatus.labelAr(s)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _saving
                            ? null
                            : (String? v) {
                                if (v != null) {
                                  setState(() => _exitStatus = v);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'priority = 1، type = main_checkpoint تلقائياً.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _EditCheckpointDialog extends StatefulWidget {
  const _EditCheckpointDialog({required this.checkpoint});

  final Checkpoint checkpoint;

  @override
  State<_EditCheckpointDialog> createState() => _EditCheckpointDialogState();
}

class _EditCheckpointDialogState extends State<_EditCheckpointDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameArCtrl;
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _cityManualCtrl;
  late final TextEditingController _aliasesCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  String? _selectedCity;
  bool _loadingDoc = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _nameArCtrl = TextEditingController(text: widget.checkpoint.id);
    _nameEnCtrl = TextEditingController();
    _cityManualCtrl = TextEditingController();
    _aliasesCtrl = TextEditingController();
    final double? la = widget.checkpoint.latitude;
    final double? lo = widget.checkpoint.longitude;
    _latCtrl = TextEditingController(text: la != null ? '$la' : '');
    _lngCtrl = TextEditingController(text: lo != null ? '$lo' : '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  @override
  void dispose() {
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _cityManualCtrl.dispose();
    _aliasesCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final CheckpointProvider cp =
        Provider.of<CheckpointProvider>(context, listen: false);
    try {
      final Map<String, dynamic> d =
          await cp.getCheckpointDocument(widget.checkpoint.id);
      final Object? ne = d['name_en'] ?? d['nameEn'];
      if (ne is String && ne.trim().isNotEmpty) {
        _nameEnCtrl.text = ne.trim();
      }
      final Object? rawAliases = d['aliases'];
      if (rawAliases is List<dynamic>) {
        final List<String> parts = rawAliases
            .map((Object? e) => e?.toString().trim() ?? '')
            .where((String s) => s.isNotEmpty)
            .toList();
        _aliasesCtrl.text = parts.join('\n');
      }
      final List<String> cities = _distinctCheckpointCities(cp.items);
      final String loc = widget.checkpoint.location.trim();
      if (cities.isNotEmpty) {
        if (cities.contains(loc)) {
          _selectedCity = loc;
        } else {
          _cityManualCtrl.text = loc;
        }
      } else {
        _cityManualCtrl.text = loc;
      }
    } catch (e) {
      _loadError = '$e';
    }
    if (mounted) {
      setState(() => _loadingDoc = false);
    }
  }

  String _aliasesPreview() {
    return CheckpointRepository.mergeAliases(
      nameAr: _nameArCtrl.text.trim(),
      nameEn: _nameEnCtrl.text,
      extraRaw: _aliasesCtrl.text,
    ).join('، ');
  }

  double? _parseCoord(String? raw) {
    if (raw == null) {
      return null;
    }
    return double.tryParse(raw.trim().replaceAll(',', '.'));
  }

  Future<bool?> _confirmRename(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تغيير الاسم العربي؟'),
            content: const Text(
              'سيتم إنشاء وثيقة جديدة بمعرّف الاسم الجديد وحذف الوثيقة الحالية، مع الاحتفاظ بحالة الحاجز وسجل التحديثات والحقول الأخرى.',
              textAlign: TextAlign.right,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('متابعة'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final double? lat = _parseCoord(_latCtrl.text);
    final double? lng = _parseCoord(_lngCtrl.text);
    if (lat == null || lng == null) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState nav = Navigator.of(context);
    final CheckpointProvider cp = context.read<CheckpointProvider>();
    final List<String> cities = _distinctCheckpointCities(cp.items);
    late final String cityValue;
    if (cities.isEmpty) {
      cityValue = _cityManualCtrl.text.trim();
    } else if (_cityManualCtrl.text.trim().isNotEmpty) {
      cityValue = _cityManualCtrl.text.trim();
    } else if (_selectedCity != null &&
        cities.contains(_selectedCity)) {
      cityValue = _selectedCity!.trim();
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('اختر المدينة أو أضف اسمها')),
      );
      return;
    }

    final String newNameAr = _nameArCtrl.text.trim();
    final String oldId = widget.checkpoint.id;
    if (newNameAr.contains('/')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('لا يُسمح بالرمز «/» في الاسم العربي')),
      );
      return;
    }

    if (newNameAr != oldId) {
      final bool? ok = await _confirmRename(context);
      if (ok != true) {
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (newNameAr == oldId) {
        await cp.updateCheckpointMeta(
          documentId: oldId,
          nameEn: _nameEnCtrl.text,
          latitude: lat,
          longitude: lng,
          city: cityValue,
          extraAliases: _aliasesCtrl.text,
        );
      } else {
        await cp.migrateCheckpointDocument(
          oldDocumentId: oldId,
          newNameAr: newNameAr,
          nameEn: _nameEnCtrl.text,
          latitude: lat,
          longitude: lng,
          city: cityValue,
          extraAliases: _aliasesCtrl.text,
        );
      }
      if (!mounted) {
        return;
      }
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckpointProvider cp = context.watch<CheckpointProvider>();
    final List<String> cities = _distinctCheckpointCities(cp.items);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تعديل معلومات الحاجز'),
        content: SizedBox(
          width: 420,
          child: _loadingDoc
              ? const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _loadError != null
                  ? Text(
                      _loadError!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.right,
                    )
                  : SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextFormField(
                              controller: _nameArCtrl,
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                labelText: 'الاسم بالعربي (معرّف الوثيقة)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (String? v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'مطلوب';
                                }
                                if (v.trim().contains('/')) {
                                  return 'لا يُسمح بالرمز «/»';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameEnCtrl,
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                labelText: 'الاسم بالإنجليزي',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),
                            if (cities.isEmpty)
                              TextFormField(
                                controller: _cityManualCtrl,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  labelText: 'المدينة',
                                  border: OutlineInputBorder(),
                                ),
                              )
                            else
                              InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'المدينة',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedCity != null &&
                                            cities.contains(_selectedCity)
                                        ? _selectedCity
                                        : null,
                                    hint: const Text(
                                      'اختر مدينة',
                                      textAlign: TextAlign.right,
                                    ),
                                    items: cities
                                        .map(
                                          (String city) =>
                                              DropdownMenuItem<String>(
                                            value: city,
                                            child: Text(
                                              city,
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: _saving
                                        ? null
                                        : (String? v) => setState(
                                              () => _selectedCity = v,
                                            ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _cityManualCtrl,
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                labelText:
                                    'أو أدخل اسم المدينة يدوياً إذا غير مدرجة',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _aliasesCtrl,
                              textAlign: TextAlign.right,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'أسماء بديلة (فاصلة أو سطر جديد)',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'سيُحفظ كـ aliases: ${_aliasesPreview().isEmpty ? '—' : _aliasesPreview()}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextFormField(
                                    controller: _latCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'خط العرض',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (String? v) {
                                      if (_parseCoord(v) == null) {
                                        return 'رقم صالح';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lngCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'خط الطول',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (String? v) {
                                      if (_parseCoord(v) == null) {
                                        return 'رقم صالح';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: (_saving || _loadingDoc)
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: (_saving ||
                    _loadingDoc ||
                    _loadError != null)
                ? null
                : _submit,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
