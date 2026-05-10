import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/saved_checkpoints_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/checkpoint_saved_subtitle_ar.dart';
import '../../utils/guest_session.dart';
import '../widgets/reference_checkpoint_tile.dart';
import 'checkpoint_detail_screen.dart';

Future<void> _toggleSavedRemoval(
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

/// صفحة «المثبتة»؛ يُفضَّل أن يصل إليها المستخدم المُسجَّل فقط (تُحمى من الزوار).
class SavedCheckpointsScreen extends StatefulWidget {
  const SavedCheckpointsScreen({super.key});

  @override
  State<SavedCheckpointsScreen> createState() => _SavedCheckpointsScreenState();
}

class _SavedCheckpointsScreenState extends State<SavedCheckpointsScreen> {
  bool _checkedGuestGate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_checkedGuestGate || !mounted) {
        return;
      }
      _checkedGuestGate = true;
      if (canUserMakeCheckpointWrites) {
        return;
      }
      await showSavedLoginRequiredDialog(context);
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!canUserMakeCheckpointWrites) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.shellBackground,
          appBar: AppBar(
            leading: BackButton(color: AppColors.textPrimaryLight),
            title: const Text('المثبتة'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.shellBackground,
        appBar: AppBar(
          backgroundColor: AppColors.cardLight,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: BackButton(color: AppColors.textPrimaryLight),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.bookmark_rounded,
                color: AppColors.brandTealDark,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'المثبتة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: Consumer2<SavedCheckpointsProvider, CheckpointProvider>(
          builder:
              (_, SavedCheckpointsProvider saved, CheckpointProvider cp, Widget? child) {
            if (cp.loading && cp.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<String> orderedIds =
                saved.ids.toList(growable: false)..sort();
            final Map<String, Checkpoint> byId = <String, Checkpoint>{
              for (final Checkpoint c in cp.items) c.id: c,
            };

            if (orderedIds.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'لم تُثبَّت أي حواجز بعد.\nاضغط أيقونة العلامة على البطاقة لإضافة حاجز هنا.',
                    textAlign: TextAlign.center,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textMutedLight,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.pagePaddingH,
                14,
                AppLayout.pagePaddingH,
                24,
              ),
              itemCount: orderedIds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext ctx, int i) {
                final String id = orderedIds[i];
                final Checkpoint? c = byId[id];
                if (c != null) {
                  return _LiveSavedCard(
                    checkpoint: c,
                    onOpenDetail: () {
                      Navigator.of(ctx).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CheckpointDetailScreen(initialCheckpoint: c),
                        ),
                      );
                    },
                    onRemovePinned: () => unawaited(
                      _toggleSavedRemoval(ctx, saved, id),
                    ),
                  );
                }
                return Card(
                  color: AppColors.cardLight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'حاجز غير متوفِّر (${id.trim()})',
                          style:
                              Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'قد يكون الحاجز غير موجود بعد أن ثبّته، أو تتأخر مزامنة القائمة.',
                          style:
                              Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMutedLight,
                                  ),
                        ),
                        TextButton.icon(
                          onPressed: () => unawaited(
                            _toggleSavedRemoval(ctx, saved, id),
                          ),
                          icon: const Icon(Icons.bookmark_remove_rounded),
                          label:
                              const Text('إزالة من المثبتة'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LiveSavedCard extends StatelessWidget {
  const _LiveSavedCard({
    required this.checkpoint,
    required this.onOpenDetail,
    required this.onRemovePinned,
  });

  final Checkpoint checkpoint;
  final VoidCallback onOpenDetail;
  final VoidCallback onRemovePinned;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = savedCheckpointSubtitleLines(checkpoint);
    return ReferenceCheckpointTile(
      checkpoint: checkpoint,
      compact: false,
      stripColor: checkpointStripColor(checkpoint),
      subtitle: lines.join('\n'),
      subtitleMaxLines: 12,
      isSaved: true,
      onSavedTap: () async => onRemovePinned(),
      isFavorite: false,
      onFavoriteTap: null,
      onCardTap: onOpenDetail,
    );
  }
}
