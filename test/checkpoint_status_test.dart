import 'package:flutter_test/flutter_test.dart';
import 'package:checkpoint_app/models/checkpoint.dart';

void main() {
  group('CheckpointStatus.normalize', () {
    test('accepts all canonical values case-insensitively', () {
      expect(CheckpointStatus.normalize('OPEN'), CheckpointStatus.open);
      expect(CheckpointStatus.normalize('Crowded'), CheckpointStatus.crowded);
      expect(
        CheckpointStatus.normalize('ARMY_PRESENT'),
        CheckpointStatus.armyPresent,
      );
      expect(
        CheckpointStatus.normalize('Settlers_PRESENT'),
        CheckpointStatus.settlersPresent,
      );
    });

    test('unknown strings fall back to open', () {
      expect(CheckpointStatus.normalize('bogus'), CheckpointStatus.open);
      expect(CheckpointStatus.normalize(''), CheckpointStatus.open);
    });
  });

  group('CheckpointStatus labels', () {
    test('crowded uses أزمة wording', () {
      expect(CheckpointStatus.labelAr(CheckpointStatus.crowded), 'أزمة');
      expect(CheckpointStatus.badgeLabelAr(CheckpointStatus.crowded), 'أزمة ~');
    });

    test('new statuses have Arabic labels', () {
      expect(CheckpointStatus.labelAr(CheckpointStatus.armyPresent), 'جيش');
      expect(
        CheckpointStatus.labelAr(CheckpointStatus.settlersPresent),
        'مستوطنون',
      );
      expect(
        CheckpointStatus.badgeLabelAr(CheckpointStatus.armyPresent),
        'جيش ⚠',
      );
    });
  });

  group('CheckpointStatus.all', () {
    test('contains five statuses', () {
      expect(CheckpointStatus.all.length, 5);
      expect(CheckpointStatus.all, contains(CheckpointStatus.armyPresent));
      expect(CheckpointStatus.all, contains(CheckpointStatus.settlersPresent));
    });
  });

  group('CheckpointReportTag.normalizeList', () {
    test('keeps allowed keys case-insensitive and sorts', () {
      expect(
        CheckpointReportTag.normalizeList(<String>[
          'BAD_WEATHER',
          'inspection',
        ]),
        <String>['bad_weather', 'inspection'],
      );
    });

    test('drops unknown keys', () {
      expect(
        CheckpointReportTag.normalizeList(<String>['hack', 'inspection']),
        <String>['inspection'],
      );
    });
  });

  group('Checkpoint.readReportTags', () {
    test('returns empty when field missing', () {
      expect(Checkpoint.readReportTags(<String, dynamic>{}), isEmpty);
    });

    test('reads reportTags and filters', () {
      final List<String> r = Checkpoint.readReportTags(<String, dynamic>{
        'reportTags': <dynamic>['inspection', 'unknown', 'traffic_density'],
      });
      expect(r, <String>['inspection', 'traffic_density']);
    });

    test('accepts report_tags snake_case', () {
      final List<String> r = Checkpoint.readReportTags(<String, dynamic>{
        'report_tags': <dynamic>['maintenance'],
      });
      expect(r, <String>['maintenance']);
    });
  });
}
