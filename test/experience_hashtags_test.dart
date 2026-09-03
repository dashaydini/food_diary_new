import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/utils/experience_hashtags.dart';
import 'package:food_diary/utils/hashtag_taste_profile.dart';

void main() {
  const notes = 'קיבלנו חמוצים וצ׳יפס בצד, שירות אדיב ומהיר. מקום נקי\n'
      'קצת יקר לאוכל רחוב\n#שניצל #שווארמה #אוכל_רחוב';
  const place = {'name': 'בית הפול הירוק - נווה זאב', 'address': 'באר שבע'};
  final tags = ExperienceHashtags.extract(notes);

  test('extracts existing Beit Hapol hashtags without changing notes', () {
    expect(tags, ['שניצל', 'שווארמה', 'אוכל_רחוב']);
    expect(ExperienceHashtags.extract(null), isEmpty);
    expect(ExperienceHashtags.extract('אין האשטאגים'), isEmpty);
  });
  test('deduplicates case, Hebrew vowels and surrounding punctuation', () {
    expect(
        ExperienceHashtags.extract(
            '(#שניצל), #שְׁנִיצֶל! #Coffee #coffee #בראנץ׳'),
        ['שניצל', 'coffee', 'בראנץ׳']);
  });
  test('ignores URL fragments and inline non-hashtag hashes', () {
    expect(
        ExperienceHashtags.extract('https://example.org/#section abc#tag #_ #'),
        isEmpty);
  });
  test('search works with or without hash; spaces match underscores', () {
    for (final query in ['שניצל', '#שניצל', 'אוכל רחוב', '#אוכל_רחוב']) {
      expect(ExperienceHashtags.matchesPlace(place, tags, query), isTrue,
          reason: query);
    }
  });
  test('explicit hashtag is exact and never matches place-name text', () {
    expect(ExperienceHashtags.matchesPlace(place, tags, '#שניצ'), isFalse);
    expect(ExperienceHashtags.matchesPlace(place, tags, '#בית'), isFalse);
    expect(ExperienceHashtags.matchesPlace(place, tags, '#'), isFalse);
    expect(ExperienceHashtags.matchesPlace(place, tags, '#שניצל #שווארמה'),
        isTrue);
    expect(
        ExperienceHashtags.matchesPlace(place, tags, '#שניצל #פיצה'), isFalse);
  });
  test('ordinary place search and empty search still work', () {
    expect(ExperienceHashtags.matchesPlace(place, tags, 'בית הפול'), isTrue);
    expect(ExperienceHashtags.matchesPlace(place, tags, 'באר שבע'), isTrue);
    expect(ExperienceHashtags.matchesPlace(place, tags, ''), isTrue);
    expect(ExperienceHashtags.matchesPlace(place, tags, 'פיצה'), isFalse);
    expect(ExperienceHashtags.matching(tags, ''), isEmpty);
  });
  test(
      'place index never reads private journal notes and handles edits/removals',
      () {
    final rows = [
      {'place_id': 'p', 'notes': '#שניצל #שניצל', 'journal_note': '#סודי'},
      {'place_id': 'p', 'notes': '#שווארמה'},
      {'place_id': 'other', 'notes': '#פיצה'},
    ];
    expect(ExperienceHashtags.byPlace(rows)['p'], {'שניצל', 'שווארמה'});
    rows[0]['notes'] = 'בלי האשטאג';
    expect(ExperienceHashtags.byPlace(rows)['p'], {'שווארמה'});
    rows.removeAt(1);
    expect(ExperienceHashtags.byPlace(rows).containsKey('p'), isFalse);
  });
  test('unrated mention is neutral, not a taste preference', () {
    final profile = HashtagTasteProfile.fromVisits([
      {'place_id': 'p', 'notes': '#שניצל'},
    ], {});
    expect(profile.stats.single.places, 1);
    expect(profile.scoreFor(['שניצל']), 0);
    expect(profile.positiveMatches(['שניצל']), isEmpty);
  });
  test('explicit dislike overrides high rating and reduces candidate score',
      () {
    final profile = HashtagTasteProfile.fromVisits([
      {'place_id': 'p', 'notes': '#שניצל', 'rating': 5},
    ], {
      'p': -1
    });
    expect(profile.stats.single.negative, 1);
    expect(profile.stats.single.positive, 0);
    expect(profile.scoreFor(['שניצל']), lessThan(0));
  });
  test('positive evidence counts unique places, not repeated tags or visits',
      () {
    final profile = HashtagTasteProfile.fromVisits([
      {'place_id': 'p', 'notes': '#שניצל #שניצל', 'rating': 4.5},
      {'place_id': 'p', 'notes': '#שניצל', 'rating': 4.5},
    ], {});
    expect(profile.stats.single.places, 1);
    expect(profile.stats.single.positive, 1);
    expect(profile.scoreFor(['שניצל', 'שניצל']), 0.5);
    expect(profile.scoreFor(['פיצה']), 0);
  });
  test('opposing evidence stays neutral and explicit like overrides low rating',
      () {
    final visits = [
      {'place_id': 'a', 'notes': '#שניצל', 'rating': 1},
      {'place_id': 'b', 'notes': '#שניצל', 'rating': 2},
    ];
    final profile = HashtagTasteProfile.fromVisits(visits, {'a': 1});
    expect(profile.stats.single.positive, 1);
    expect(profile.stats.single.negative, 1);
    expect(profile.scoreFor(['שניצל']), 0);
  });
}
