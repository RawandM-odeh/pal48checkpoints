import 'package:flutter/material.dart';

import '../../models/checkpoint.dart';

/// دائرة مقسومة: النصف الأيسر = دخول، الأيمن = خروج (نفس ألوان القائمة).
///
/// يُستخدم [LinearGradient] بدل [ClipOval]+صف لأن طبقة علامات [flutter_map]
/// (خصوصاً على الويب) قد لا ترسم الأطفال الداخليين بألوان صحيحة وتظهر دوائر رمادية.
class SplitCheckpointPin extends StatelessWidget {
  const SplitCheckpointPin({
    super.key,
    required this.entranceStatus,
    required this.exitStatus,
    this.size = 30,
  });

  final String entranceStatus;
  final String exitStatus;
  final double size;

  static Color _solid(String status) {
    switch (CheckpointStatus.normalize(status)) {
      case CheckpointStatus.closed:
        return const Color(0xFFC62828);
      case CheckpointStatus.crowded:
        return const Color(0xFFF9A825);
      case CheckpointStatus.armyPresent:
        return const Color(0xFFF59E0B);
      case CheckpointStatus.settlersPresent:
        return const Color(0xFF9333EA);
      case CheckpointStatus.open:
      default:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color left = _solid(entranceStatus);
    final Color right = _solid(exitStatus);
    final double borderW = size >= 26 ? 1.75 : 1.25;
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[left, right],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(color: Colors.white, width: borderW),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: size * 0.12,
                offset: Offset(0, size * 0.06),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
