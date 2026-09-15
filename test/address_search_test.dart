import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/utils/address_search.dart';

void main() {
  group('address search query', () {
    test('adds Israel to a settlement search', () {
      expect(
        buildAddressSearchQuery(address: 'ערוגות'),
        'ערוגות, ישראל',
      );
    });

    test('removes the business name and moshav prefix', () {
      expect(
        buildAddressSearchQuery(
          address: 'ג׳חבורג, מושב ערוגות',
          placeName: "ג'חבורג",
        ),
        'ערוגות, ישראל',
      );
    });

    test('removes a joined bemoshav prefix', () {
      expect(
        buildAddressSearchQuery(
          address: 'ג׳חבורג במושב ערוגות',
          placeName: 'ג׳חבורג',
        ),
        'ערוגות, ישראל',
      );
    });

    test('keeps a regular street address intact', () {
      expect(
        buildAddressSearchQuery(address: 'הרצל 10, תל אביב'),
        'הרצל 10, תל אביב, ישראל',
      );
    });
  });
}
