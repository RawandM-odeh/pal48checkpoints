import 'package:flutter/material.dart';

import '../../models/checkpoint.dart';

/// Horizontal segment control: open / closed / crowded («مفتوح / مغلق / مزدحم»).
class DirectionStatusSegments extends StatelessWidget {
  const DirectionStatusSegments({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final String normalized =
        CheckpointStatus.normalize(selected);

    return SegmentedButton<String>(
      showSelectedIcon: false,
      emptySelectionAllowed: false,
      multiSelectionEnabled: false,
      segments: CheckpointStatus.all
          .map(
            (String s) => ButtonSegment<String>(
              value: s,
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: CheckpointStatus.dotColor(context, s),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      CheckpointStatus.labelAr(s),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
              tooltip: CheckpointStatus.labelAr(s),
            ),
          )
          .toList(growable: false),
      selected: <String>{normalized},
      onSelectionChanged: (Set<String> next) {
        if (next.isEmpty) {
          return;
        }
        onChanged(CheckpointStatus.normalize(next.first));
      },
    );
  }
}
