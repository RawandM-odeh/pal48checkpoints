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
    if (_cityFilter == null) {
      return items;
    }
    return items
        .where((Checkpoint c) => c.location.trim() == _cityFilter)
        .toList(growable: false);
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
                  color: CheckpointCardStyle.navy.withValues(alpha: 0.6),
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
                  children: <Widget>[
                    const Icon(Icons.location_city_outlined, size: 22),
                    const SizedBox(width: 8),
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
                                (String city) => DropdownMenuItem<String?>(
                                  value: city,
                                  child: Text(city, textAlign: TextAlign.right),
                                ),
                              ),
                            ],
                            onChanged: (String? v) =>
                                setState(() => _cityFilter = v),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد حواجز لهذه المدينة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: CheckpointCardStyle.navy.withValues(
                              alpha: 0.55,
                            ),
                          ),
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
                            onStatusBadgeTap: (String direction) =>
                                _onBadgeTap(context, c, direction),
                            onCardTap: () => _openDetail(context, c),
                            trailing: const SizedBox(width: 26),
                            footer: TextButton.icon(
                              onPressed: () => _confirmDelete(context, c),
                              icon: const Text(
                                '🗑️',
                                style: TextStyle(fontSize: 18),
                              ),
                              label: const Text('حذف'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
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

String _statusLabelAr(String s) {
  switch (CheckpointStatus.normalize(s)) {
    case CheckpointStatus.closed:
      return 'مغلق';
    case CheckpointStatus.crowded:
      return 'مزدحم';
    case CheckpointStatus.open:
    default:
      return 'سالك';
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
                                child: Text(_statusLabelAr(s)),
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
                                child: Text(_statusLabelAr(s)),
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
