import 'package:flutter_test/flutter_test.dart';
import 'package:checkpoint_app/utils/city_display_ar.dart';

void main() {
  test('Salfit variants map to سلفيت', () {
    expect(cityDisplayNameAr('Salfit'), 'سلفيت');
    expect(cityDisplayNameAr('salfit'), 'سلفيت');
    expect(cityDisplayNameAr('SALFIT'), 'سلفيت');
    expect(cityDisplayNameAr(' Salfit '), 'سلفيت');
    expect(cityDisplayNameAr('Salfit Governorate'), 'سلفيت');
    expect(cityDisplayNameAr('Salfeet'), 'سلفيت');
  });

  test('other cities still map', () {
    expect(cityDisplayNameAr('Bethlehem'), 'بيت لحم');
    expect(cityDisplayNameAr('jerusalem'), 'القدس');
  });
}
