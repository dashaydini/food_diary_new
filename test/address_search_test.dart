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

  test('prefers an exact settlement node over an administrative result', () {
    final result = selectBestAddressSearchResult(
      [
        {
          'name': 'מועצה אזורית באר טוביה',
          'category': 'boundary',
          'type': 'administrative',
          'addresstype': 'municipality',
          'osm_type': 'relation',
          'lat': '31.70',
          'lon': '34.75',
          'address': {'municipality': 'מועצה אזורית באר טוביה'},
        },
        {
          'name': 'ערוגות',
          'category': 'place',
          'type': 'village',
          'addresstype': 'village',
          'osm_type': 'node',
          'lat': '31.7346866',
          'lon': '34.7708779',
          'address': {'village': 'ערוגות'},
        },
      ],
      query: 'ערוגות, ישראל',
    );

    expect(result?['name'], 'ערוגות');
    expect(result?['lat'], '31.7346866');
  });
}
