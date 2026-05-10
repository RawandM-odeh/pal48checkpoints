import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkpoint.dart';
import '../../providers/checkpoint_provider.dart';
import '../../providers/favorite_checkpoints_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/guest_session.dart';
import '../../utils/ar_relative_time.dart';
import '../widgets/reference_checkpoint_tile.dart';
import '../widgets/checkpoint_card.dart';
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

DateTime? _favoriteLatestUpdate(Checkpoint c) {
  final DateTime? a = c.entranceUpdatedAt;
  final DateTime? b = c.exitUpdatedAt;
  if (a != null && b != null) {
    return a.isAfter(b) ? a : b;
  }
  return a ?? b;
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FavoriteCheckpointsProvider favorites = context
        .watch<FavoriteCheckpointsProvider>();
    final CheckpointProvider cp = context.watch<CheckpointProvider>();

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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.favorite_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.85),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'المفضلة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: _FavoritesBody(favorites: favorites, checkpoints: cp),
      ),
    );
  }
}

class _FavoritesBody extends StatelessWidget {
  const _FavoritesBody({required this.favorites, required this.checkpoints});

  final FavoriteCheckpointsProvider favorites;
  final CheckpointProvider checkpoints;

  @override
  Widget build(BuildContext context) {
    if (!canUserMakeCheckpointWrites) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Please log in to view and manage favorite checkpoints.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textMutedLight,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () =>
                    unawaited(showLoginRequiredDialog(context)),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    if (checkpoints.loading && checkpoints.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (favorites.ids.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No favorite checkpoints yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textMutedLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final Map<String, Checkpoint> byId = <String, Checkpoint>{
      for (final Checkpoint c in checkpoints.items) c.id: c,
    };

    final List<String> idsSorted = favorites.ids.toList()..sort();

    final List<_FavResolved> resolved = idsSorted.map((String id) {
      final Checkpoint? live = byId[id];
      return live != null ? _FavResolved.ok(live) : _FavResolved.missing(id);
    }).toList();

    resolved.sort((_FavResolved a, _FavResolved b) {
      final Checkpoint? ca = a.checkpoint;
      final Checkpoint? cb = b.checkpoint;
      if (ca != null && cb != null) {
        return ca.name.toLowerCase().compareTo(cb.name.toLowerCase());
      }
      if (ca != null) return -1;
      if (cb != null) return 1;
      return a.missingId!.compareTo(b.missingId!);
    });

    final ThemeData theme = Theme.of(context);
    final FavoriteCheckpointsProvider favRead = context
        .read<FavoriteCheckpointsProvider>();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: resolved.length,
      itemBuilder: (BuildContext context, int i) {
        final _FavResolved item = resolved[i];
        final Checkpoint? c = item.checkpoint;

        if (c == null) {
          final String id = item.missingId!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      id,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'غير موجود في قائمة الحواجز الحالية',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMutedLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () =>
                          unawaited(_toggleFavoriteLoggedInIfAllowed(
                        context,
                        favRead,
                        id,
                      )),
                      icon: const Icon(Icons.heart_broken_rounded),
                      label: const Text('إزالة من المفضلة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final String subtitle = arabicRelativeSince(_favoriteLatestUpdate(c));

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ReferenceCheckpointTile(
            checkpoint: c,
            compact: false,
            stripColor: checkpointStripColor(c),
            subtitle: subtitle,
            isFavorite: true,
            onFavoriteTap: () => _toggleFavoriteLoggedInIfAllowed(
                  context,
                  favRead,
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
                  builder: (_) => CheckpointDetailScreen(initialCheckpoint: c),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FavResolved {
  _FavResolved._({this.checkpoint, this.missingId});

  final Checkpoint? checkpoint;
  final String? missingId;

  factory _FavResolved.ok(Checkpoint c) =>
      _FavResolved._(checkpoint: c, missingId: null);

  factory _FavResolved.missing(String id) =>
      _FavResolved._(checkpoint: null, missingId: id);
}
