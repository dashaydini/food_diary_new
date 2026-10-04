import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/place_card.dart';

/// Local-only preview for evaluating an OpenStreetMap-style place import.
/// It is enabled exclusively with LOCAL_IMPORT_PREVIEW=true and never writes
/// data to Supabase or appears in a release build.
class LocalImportPreviewApp extends StatelessWidget {
  const LocalImportPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BITE THE WAY · Preview',
      theme: AppTheme.darkTheme,
      locale: const Locale('he', 'IL'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const LocalImportPreviewScreen(),
    );
  }
}

class LocalImportPreviewScreen extends StatelessWidget {
  const LocalImportPreviewScreen({super.key});

  static const _places = <Map<String, dynamic>>[
    {
      'id': 'osm-7637925185',
      'name': "فينجان פינג'אן קפה",
      'address': 'יהודה מרגוזה 28, יפו, תל־אביב–יפו',
      'description': 'בית קפה · נתוני OpenStreetMap',
      'category_id': 'coffee',
      'latitude': 32.0513964,
      'longitude': 34.7542677,
      'rating_count': 0,
    },
    {
      'id': 'osm-5604815954',
      'name': 'קפה ברזילי',
      'address': 'מקווה ישראל 12, תל־אביב–יפו',
      'description': 'בית קפה · נתוני OpenStreetMap',
      'category_id': 'coffee',
      'latitude': 32.0623776,
      'longitude': 34.7752236,
      'rating_count': 0,
    },
    {
      'id': 'osm-5949688775',
      'name': 'בייקרי',
      'address': 'ויצמן, תל־אביב–יפו',
      'description': 'מאפייה · נתוני OpenStreetMap',
      'category_id': 'bakery',
      'latitude': 32.0881861,
      'longitude': 34.7898622,
      'rating_count': 0,
    },
    {
      'id': 'osm-6213272685',
      'name': 'Jonas Jaffa Restaurant',
      'address': 'שארית ישראל, יפו, תל־אביב–יפו',
      'description': 'מסעדה · נתוני OpenStreetMap',
      'category_id': 'restaurant',
      'latitude': 32.0523573,
      'longitude': 34.7626219,
      'rating_count': 0,
    },
    {
      'id': 'osm-2139853804',
      'name': 'סתווים - Stivim Restaurant - Coin Commerce',
      'address': 'אחוזת בית 3, תל־אביב–יפו',
      'description': 'מסעדה · נתוני OpenStreetMap',
      'category_id': 'restaurant',
      'latitude': 32.0645717,
      'longitude': 34.7705798,
      'rating_count': 0,
    },
    {
      'id': 'osm-4427835291',
      'name': 'Russian Restaurant',
      'address': 'בן יהודה 6, תל־אביב–יפו',
      'description': 'מסעדה · נתוני OpenStreetMap',
      'category_id': 'restaurant',
      'latitude': 32.0736730,
      'longitude': 34.7684099,
      'rating_count': 0,
    },
    {
      'id': 'osm-2488500503',
      'name': 'مطعم',
      'address': 'עין חוד, חוף הכרמל',
      'description': 'מסעדה · נתוני OpenStreetMap',
      'category_id': 'restaurant',
      'latitude': 32.6900890,
      'longitude': 35.0002930,
      'rating_count': 0,
    },
    {
      'id': 'osm-1703936209',
      'name': 'מסעדת open',
      'address': 'שלמה המלך, ירושלים',
      'description': 'מסעדה · נתוני OpenStreetMap',
      'category_id': 'restaurant',
      'latitude': 31.7783969,
      'longitude': 35.2231031,
      'rating_count': 0,
    },
    {
      'id': 'osm-7233474633',
      'name': 'Restaurant Rose',
      'address': 'שמעון בר גיורא, באר שבע',
      'description': 'מסעדה · נתוני OpenStreetMap',
      'category_id': 'restaurant',
      'latitude': 31.2605140,
      'longitude': 34.7875227,
      'rating_count': 0,
    },
    {
      'id': 'osm-1299993292',
      'name': 'Optimi diary restaurant',
      'address': 'טיילת השלום, אילת',
      'description': 'מסעדה · נתוני OpenStreetMap',
      'category_id': 'restaurant',
      'latitude': 29.5507146,
      'longitude': 34.9554062,
      'rating_count': 0,
    },
    {
      'id': 'osm-1299862149',
      'name': 'GULF Restaurant',
      'address': 'התורן, אילת',
      'description': 'מסעדה · נתוני OpenStreetMap',
      'category_id': 'restaurant',
      'latitude': 29.5508639,
      'longitude': 34.9593115,
      'rating_count': 0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('תצוגת יבוא מקומות'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: .18),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('מדגם רשומות מיקום מ־OpenStreetMap',
                    textAlign: TextAlign.right,
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                SizedBox(height: 5),
                Text(
                  '11 רשומות מצפון, מרכז, ירושלים ודרום. הנתונים אינם אימות שהמקום פעיל כיום; אין כאן דירוגים או תמונות מועתקים. © OpenStreetMap contributors',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._places.map(
            (place) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PlaceCard(place: place),
            ),
          ),
        ],
      ),
    );
  }
}
