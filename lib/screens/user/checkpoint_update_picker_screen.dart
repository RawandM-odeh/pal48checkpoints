import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/favorite_checkpoints_provider.dart';
import '../../providers/saved_checkpoints_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/ar_relative_time.dart';
import '../../utils/checkpoint_search.dart';
import '../../utils/guest_session.dart';
import '../widgets/checkpoint_card.dart';
import '../widgets/reference_checkpoint_tile.dart';
import 'checkpoint_detail_screen.dart';

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

/// اختيار حاجز ثم التعديل في تبويب «أرسل تحديث».
class CheckpointUpdatePickerScreen extends StatefulWidget {
  const CheckpointUpdatePickerScreen({super.key});

  @override
  State<CheckpointUpdatePickerScreen> createState() =>
      _CheckpointUpdatePickerScreenState();
}

class _CheckpointUpdatePickerScreenState
    extends State<CheckpointUpdatePickerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Checkpoint> _sortedFiltered(List<Checkpoint> items, String rawQ) {
    final String ql = rawQ.trim().toLowerCase();
    Iterable<Checkpoint> out = items;
    if (ql.isNotEmpty) {
      out = out.where((Checkpoint c) => checkpointMatchesUserSearch(c, ql));
    }
    final List<Checkpoint> list = out.toList(growable: false);
    list.sort(
      (Checkpoint a, Checkpoint b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final CheckpointProvider cp = context.watch<CheckpointProvider>();
    final FavoriteCheckpointsProvider favorites = context
        .watch<FavoriteCheckpointsProvider>();
    final SavedCheckpointsProvider saved = context.watch<SavedCheckpointsProvider>();
    final ThemeData theme = Theme.of(context);
    final List<Checkpoint> rows = _sortedFiltered(cp.items, _query);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.shellBackground,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.surfaceSoft,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          leading: BackButton(
            onPressed: () => Navigator.of(context).maybePop(),
            color: AppColors.textPrimaryLight,
          ),
          title: const Text(
            'تحديث حالة حاجز',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        body: cp.loading && cp.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : cp.error != null && cp.items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    cp.error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              )
            : !cp.loading && cp.items.isEmpty
            ? Center(
                child: Text(
                  'لا توجد حواجز بعد',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textMutedLight,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      'اضغط الحاجز، ثم عِدْ حالة الدخول والخروج والوسوم واحفظ؛ يمكنك أيضاً ضغط شارة سالك/مغلق للتحديث السريع من هنا.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMutedLight,
                        height: 1.38,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppLayout.pagePaddingH,
                      0,
                      AppLayout.pagePaddingH,
                      14,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.cardLight,
                        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                        border: Border.all(color: AppColors.borderSubtleLight),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'بحث بالاسم أو الحالة أو المدينة…',
                            hintStyle: TextStyle(color: AppColors.textMutedLight),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.textMutedLight,
                            ),
                            suffixIcon: _query.trim().isNotEmpty
                                ? IconButton(
                                    tooltip: 'مسح',
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: AppColors.textMutedLight,
                                    ),
                                  )
                                : null,
                          ),
                          onChanged: (String s) => setState(() => _query = s),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'لا نتائج مطابقة لبحثك',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textMutedLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppLayout.pagePaddingH,
                              0,
                              AppLayout.pagePaddingH,
                              24,
                            ),
                            itemCount: rows.length,
                            itemBuilder: (BuildContext context, int i) {
                              final Checkpoint c = rows[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ReferenceCheckpointTile(
                                  checkpoint: c,
                                  compact: false,
                                  stripColor: checkpointStripColor(c),
                                  subtitle:
                                      arabicRelativeSince(c.latestDirectionalUpdate),
                                  isSaved: saved.isSaved(c.id),
                                  onSavedTap: () =>
                                      _toggleSavedLoggedInIfAllowed(
                                          context,
                                          saved,
                                          c.id,
                                      ),
                                  isFavorite: favorites.isFavorite(c.id),
                                  onFavoriteTap: () =>
                                      _toggleFavoriteLoggedInIfAllowed(
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
                                        builder: (_) =>
                                            CheckpointDetailScreen(
                                          initialCheckpoint: c,
                                          initialTabIndex: 1,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
