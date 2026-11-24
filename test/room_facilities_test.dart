import 'package:flutter_test/flutter_test.dart';
import 'package:kosmate/core/constants/room_facilities.dart';

void main() {
  group('RoomFacilities.parse', () {
    test('normalizes known names and supports legacy separators', () {
      expect(RoomFacilities.parse('single bed; Wi-Fi\nPRIVATE BATHROOM'), [
        'Single Bed',
        'Wi-Fi',
        'Private Bathroom',
      ]);
    });

    test('keeps unique unknown legacy facilities', () {
      expect(RoomFacilities.parse('AC, AC, Kamar Mandi Dalam'), [
        'AC',
        'Kamar Mandi Dalam',
      ]);
    });

    test('returns an empty list for absent facilities', () {
      expect(RoomFacilities.parse(null), isEmpty);
      expect(RoomFacilities.parse('  '), isEmpty);
    });
  });
}
