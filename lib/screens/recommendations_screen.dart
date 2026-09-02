import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';
import 'public_profile_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _client = Supabase.instance.client;

  List<_PlaceRecommendation> _recommendations = [];
  List<_PlaceRecommendation> _similarTasteRecommendations = [];
  List<_SimilarUser> _similarUsers = [];
  bool _loading = true;
  bool _hasLocation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _recommendations = [];
      });
      return;
    }

    try {
      final results = await Future.wait([
        _client
            .from('visits')
            .select('id, place_id, rating, price_level, places(category_id)')
            .eq('user_id', user.id),
        _client.from('places').select(
              'id, user_id, category_id, name, description, address, '
              'latitude, longitude, image_url, created_at, categories(title)',
            ),
        _client.from('visits').select(
              'id, place_id, user_id, rating, price_level, created_at',
            ),
        _client
            .from('user_place_preferences')
            .select('place_id, taste_feedback')
            .eq('user_id', user.id)
            .not('taste_feedback', 'is', null),
        _client.from('visit_tag_links').select('visit_id, tag_id'),
      ]);

      final ownVisits = List<Map<String, dynamic>>.from(results[0]);
      final places = List<Map<String, dynamic>>.from(results[1]);
      final allVisits = List<Map<String, dynamic>>.from(results[2]);
      final tastePreferences = List<Map<String, dynamic>>.from(results[3]);
      final allTagLinks = List<Map<String, dynamic>>.from(results[4]);

      final placesById = <String, Map<String, dynamic>>{
        for (final place in places)
          if (place['id'] != null) place['id'].toString(): place,
      };
      final likedPlaceIds = <String>{};
      final dislikedPlaceIds = <String>{};
      for (final preference in tastePreferences) {
        final placeId = preference['place_id']?.toString();
        final feedback = (preference['taste_feedback'] as num?)?.toInt();
        if (placeId == null) continue;
        if (feedback == 1) likedPlaceIds.add(placeId);
        if (feedback == -1) dislikedPlaceIds.add(placeId);
      }

      final visitedPlaceIds = <String>{};
      final categoryWeights = <String, double>{};
      var ownPriceSum = 0.0;
      var ownPriceCount = 0;

      for (final visit in ownVisits) {
        final placeId = visit['place_id']?.toString();
        if (placeId != null) visitedPlaceIds.add(placeId);

        final place = visit['places'];
        final categoryId =
            place is Map ? place['category_id']?.toString() : null;
        final rating = (visit['rating'] as num?)?.toDouble() ?? 3;
        if (categoryId != null) {
          categoryWeights[categoryId] =
              (categoryWeights[categoryId] ?? 0) + rating.clamp(1, 5);
        }

        final priceLevel = (visit['price_level'] as num?)?.toDouble();
        if (priceLevel != null && priceLevel > 0) {
          ownPriceSum += priceLevel;
          ownPriceCount++;
        }
      }

      for (final placeId in likedPlaceIds) {
        final categoryId = placesById[placeId]?['category_id']?.toString();
        if (categoryId != null) {
          categoryWeights[categoryId] = (categoryWeights[categoryId] ?? 0) + 6;
        }
      }

      final preferredPrice =
          ownPriceCount == 0 ? null : ownPriceSum / ownPriceCount;
      final ratingSums = <String, double>{};
      final ratingCounts = <String, int>{};
      final priceSums = <String, double>{};
      final priceCounts = <String, int>{};
      final priceRaters = <String, Set<String>>{};
      final visitCounts = <String, int>{};
      final latestVisits = <String, DateTime>{};
      final visitPlaceIds = <String, String>{};

      for (final visit in allVisits) {
        final placeId = visit['place_id']?.toString();
        if (placeId == null) continue;
        final visitId = visit['id']?.toString();
        if (visitId != null) visitPlaceIds[visitId] = placeId;

        visitCounts[placeId] = (visitCounts[placeId] ?? 0) + 1;
        final rating = (visit['rating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          ratingSums[placeId] = (ratingSums[placeId] ?? 0) + rating;
          ratingCounts[placeId] = (ratingCounts[placeId] ?? 0) + 1;
        }

        final price = (visit['price_level'] as num?)?.toDouble();
        if (price != null && price > 0) {
          priceSums[placeId] = (priceSums[placeId] ?? 0) + price;
          priceCounts[placeId] = (priceCounts[placeId] ?? 0) + 1;
          final raterId = visit['user_id']?.toString();
          if (raterId != null) {
            priceRaters.putIfAbsent(placeId, () => <String>{}).add(raterId);
          }
        }

        final createdAt = DateTime.tryParse(
          visit['created_at']?.toString() ?? '',
        );
        if (createdAt != null &&
            (latestVisits[placeId] == null ||
                createdAt.isAfter(latestVisits[placeId]!))) {
          latestVisits[placeId] = createdAt;
        }
      }

      final placeTags = <String, Set<String>>{};
      for (final link in allTagLinks) {
        final visitId = link['visit_id']?.toString();
        final tagId = link['tag_id']?.toString();
        final placeId = visitId == null ? null : visitPlaceIds[visitId];
        if (placeId == null || tagId == null) continue;
        placeTags.putIfAbsent(placeId, () => <String>{}).add(tagId);
      }

      final tasteAnchorIds = <String>{...likedPlaceIds};
      for (final visit in ownVisits) {
        final rating = (visit['rating'] as num?)?.toDouble();
        final placeId = visit['place_id']?.toString();
        if (placeId != null && rating != null && rating >= 4) {
          tasteAnchorIds.add(placeId);
        }
      }
      tasteAnchorIds.removeAll(dislikedPlaceIds);
      final personalEvidenceCount = tastePreferences.length +
          ownVisits.where((visit) => visit['rating'] != null).length;

      final position = await _positionIfAlreadyAllowed();
      final maxCategoryWeight = categoryWeights.values.fold<double>(
        0,
        math.max,
      );
      final recommendations = <_PlaceRecommendation>[];

      for (final rawPlace in places) {
        final placeId = rawPlace['id']?.toString();
        if (placeId == null ||
            visitedPlaceIds.contains(placeId) ||
            dislikedPlaceIds.contains(placeId)) {
          continue;
        }

        final categoryId = rawPlace['category_id']?.toString();
        final categoryWeight = categoryWeights[categoryId] ?? 0;
        final ratingCount = ratingCounts[placeId] ?? 0;
        final averageRating =
            ratingCount == 0 ? null : (ratingSums[placeId] ?? 0) / ratingCount;
        final priceCount = priceCounts[placeId] ?? 0;
        final averagePrice =
            priceCount == 0 ? null : (priceSums[placeId] ?? 0) / priceCount;
        final popularity = visitCounts[placeId] ?? 0;

        var score = 0.0;
        final reasons = <_Reason>[];

        if (categoryWeight > 0 && maxCategoryWeight > 0) {
          final contribution = categoryWeight / maxCategoryWeight * 4;
          score += contribution;
          reasons.add(_Reason(contribution, 'מתאים לקטגוריות שאהבת'));
        }

        if (preferredPrice != null && averagePrice != null) {
          final difference = (preferredPrice - averagePrice).abs();
          final contribution = math.max(0.0, 1.8 - difference * 0.65);
          score += contribution;
          reasons.add(_Reason(contribution, 'מתאים לרמת המחיר שלך'));
        }

        if (averageRating != null) {
          final contribution = averageRating / 5 * 2;
          score += contribution;
          if (averageRating >= 4) {
            reasons.add(_Reason(contribution, 'מדורג גבוה בקהילה'));
          }
        }

        if (popularity > 0) {
          final contribution = math.min(popularity, 12) / 12;
          score += contribution;
          reasons.add(_Reason(contribution, 'פופולרי בקרב משתמשים'));
        }

        final createdAt = DateTime.tryParse(
          rawPlace['created_at']?.toString() ?? '',
        );
        if (createdAt != null &&
            DateTime.now().difference(createdAt).inDays <= 90) {
          score += 1.2;
          reasons.add(const _Reason(1.2, 'מקום חדש באפליקציה'));
        }

        double? distanceMeters;
        final latitude = (rawPlace['latitude'] as num?)?.toDouble();
        final longitude = (rawPlace['longitude'] as num?)?.toDouble();
        if (position != null && latitude != null && longitude != null) {
          distanceMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            latitude,
            longitude,
          );
          if (distanceMeters <= 20000) {
            final contribution = 1.5 * (1 - distanceMeters / 20000);
            score += contribution;
            reasons.add(_Reason(contribution, 'קרוב אליך'));
          }
        }

        final category = rawPlace['categories'];
        final categoryTitle =
            category is Map ? category['title']?.toString() ?? '' : '';
        final place = <String, dynamic>{
          ...rawPlace,
          'category_title': categoryTitle,
          'weighted_rating': averageRating,
          'rating_count': ratingCount,
          'average_price_level': averagePrice,
          'price_rating_count': priceRaters[placeId]?.length ?? 0,
          if (distanceMeters != null) 'distance_meters': distanceMeters,
        };

        reasons.sort((a, b) => b.weight.compareTo(a.weight));
        String? personalTasteReason;
        var bestSimilarity = 0.0;
        Map<String, dynamic>? bestAnchor;
        for (final anchorId in tasteAnchorIds) {
          final anchor = placesById[anchorId];
          if (anchor == null) continue;

          var similarity = 0.0;
          if (anchor['category_id']?.toString() == categoryId) {
            similarity += 0.45;
          }

          final anchorTags = placeTags[anchorId] ?? const <String>{};
          final candidateTags = placeTags[placeId] ?? const <String>{};
          if (anchorTags.isNotEmpty && candidateTags.isNotEmpty) {
            final sharedTags = anchorTags.intersection(candidateTags).length;
            final combinedTags = anchorTags.union(candidateTags).length;
            similarity += sharedTags / combinedTags * 0.35;
          }

          final anchorPriceCount = priceCounts[anchorId] ?? 0;
          final anchorPrice = anchorPriceCount == 0
              ? null
              : (priceSums[anchorId] ?? 0) / anchorPriceCount;
          if (anchorPrice != null && averagePrice != null) {
            final priceMatch =
                (1 - (anchorPrice - averagePrice).abs() / 2).clamp(0.0, 1.0);
            similarity += priceMatch * 0.20;
          }

          if (similarity > bestSimilarity) {
            bestSimilarity = similarity;
            bestAnchor = anchor;
          }
        }

        if (bestAnchor != null && bestSimilarity >= 0.35) {
          final normalizedScore = (score / 10.5).clamp(0.0, 1.0);
          final rawProbability =
              55 + bestSimilarity * 28 + normalizedScore * 12;
          final evidenceConfidence = math.min(personalEvidenceCount, 5) / 5;
          final probability = (55 + (rawProbability - 55) * evidenceConfidence)
              .round()
              .clamp(55, 95);
          final anchorName = bestAnchor['name']?.toString() ?? 'מקום שאהבת';
          final candidateName = rawPlace['name']?.toString() ?? 'את המקום';
          personalTasteReason =
              'אם אהבת את $anchorName, יש סיכוי משוער של $probability% שתאהב את $candidateName · מבוסס AI';
        }

        recommendations.add(
          _PlaceRecommendation(
            place: place,
            score: score,
            reason: personalTasteReason ??
                (reasons.isEmpty
                    ? 'מקום שכדאי להכיר'
                    : reasons.take(2).map((reason) => reason.text).join(' · ')),
          ),
        );
      }

      recommendations.sort((a, b) => b.score.compareTo(a.score));

      final placeCategoryIds = <String, String>{
        for (final place in places)
          if (place['id'] != null && place['category_id'] != null)
            place['id'].toString(): place['category_id'].toString(),
      };
      final otherUserCategories = <String, Map<String, double>>{};

      for (final visit in allVisits) {
        final otherUserId = visit['user_id']?.toString();
        final placeId = visit['place_id']?.toString();
        final categoryId = placeId == null ? null : placeCategoryIds[placeId];
        if (otherUserId == null ||
            otherUserId == user.id ||
            categoryId == null) {
          continue;
        }

        final rating = (visit['rating'] as num?)?.toDouble() ?? 3;
        if (rating < 3) continue;
        final weights = otherUserCategories.putIfAbsent(
          otherUserId,
          () => <String, double>{},
        );
        weights[categoryId] = (weights[categoryId] ?? 0) + rating;
      }

      final similarities = <String, double>{};
      for (final entry in otherUserCategories.entries) {
        final similarity = _cosineSimilarity(categoryWeights, entry.value);
        if (similarity > 0.12) similarities[entry.key] = similarity;
      }

      final similarUserIds = similarities.keys.toList()
        ..sort((a, b) => similarities[b]!.compareTo(similarities[a]!));
      final topSimilarUserIds = similarUserIds.take(8).toList();
      final similarPlaceScores = <String, double>{};

      for (final visit in allVisits) {
        final otherUserId = visit['user_id']?.toString();
        final placeId = visit['place_id']?.toString();
        final rating = (visit['rating'] as num?)?.toDouble() ?? 0;
        if (otherUserId == null ||
            placeId == null ||
            visitedPlaceIds.contains(placeId) ||
            rating < 4 ||
            !topSimilarUserIds.contains(otherUserId)) {
          continue;
        }

        similarPlaceScores[placeId] = (similarPlaceScores[placeId] ?? 0) +
            (similarities[otherUserId] ?? 0) * rating;
      }

      final recommendationByPlaceId = {
        for (final recommendation in recommendations)
          recommendation.place['id']?.toString(): recommendation,
      };
      final similarPlaceIds = similarPlaceScores.keys.toList()
        ..sort(
          (a, b) => similarPlaceScores[b]!.compareTo(similarPlaceScores[a]!),
        );
      final similarTasteRecommendations = <_PlaceRecommendation>[];
      for (final placeId in similarPlaceIds) {
        final recommendation = recommendationByPlaceId[placeId];
        if (recommendation == null) continue;
        similarTasteRecommendations.add(
          _PlaceRecommendation(
            place: recommendation.place,
            score: similarPlaceScores[placeId]!,
            reason: 'פופולרי אצל אנשים עם טעם דומה',
          ),
        );
        if (similarTasteRecommendations.length == 4) break;
      }

      final similarUsers = <_SimilarUser>[];
      if (topSimilarUserIds.isNotEmpty) {
        final profileResults = await Future.wait([
          _client
              .from('profiles')
              .select('id, display_name, email, avatar_url')
              .inFilter('id', topSimilarUserIds),
          _client
              .from('user_follows')
              .select('following_id')
              .eq('follower_id', user.id),
        ]);
        final followedIds = {
          for (final row in profileResults[1] as List)
            if (row['following_id'] != null) row['following_id'].toString(),
        };

        for (final rawProfile in profileResults[0] as List) {
          final profile = Map<String, dynamic>.from(rawProfile as Map);
          final id = profile['id']?.toString();
          if (id == null || followedIds.contains(id)) continue;
          similarUsers.add(
            _SimilarUser(
              profile: profile,
              similarity: similarities[id] ?? 0,
            ),
          );
        }
        similarUsers.sort(
          (a, b) => b.similarity.compareTo(a.similarity),
        );
      }

      if (!mounted) return;
      setState(() {
        _recommendations = recommendations.take(12).toList();
        _similarTasteRecommendations = similarTasteRecommendations;
        _similarUsers = similarUsers.take(6).toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  double _cosineSimilarity(
    Map<String, double> first,
    Map<String, double> second,
  ) {
    if (first.isEmpty || second.isEmpty) return 0;
    var dot = 0.0;
    var firstMagnitude = 0.0;
    var secondMagnitude = 0.0;

    for (final value in first.values) {
      firstMagnitude += value * value;
    }
    for (final entry in second.entries) {
      secondMagnitude += entry.value * entry.value;
      dot += (first[entry.key] ?? 0) * entry.value;
    }

    if (firstMagnitude == 0 || secondMagnitude == 0) return 0;
    return dot / (math.sqrt(firstMagnitude) * math.sqrt(secondMagnitude));
  }

  Future<Position?> _positionIfAlreadyAllowed() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition();
      _hasLocation = true;
      return position;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('המלצות אישיות לפי טעמך'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.5));
    }

    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _loading = true);
            _loadRecommendations();
          },
          child: const Text('לא ניתן לטעון המלצות · נסה שוב'),
        ),
      );
    }

    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return const Center(
        child: Text('יש להתחבר כדי לקבל המלצות אישיות'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final nearby = _recommendations.where((recommendation) {
          final distance =
              (recommendation.place['distance_meters'] as num?)?.toDouble();
          return distance != null && distance <= 20000;
        }).toList();
        final nearbyIds = {
          for (final recommendation in nearby)
            recommendation.place['id']?.toString(),
        };
        final personal = _recommendations.where((recommendation) {
          return !nearbyIds.contains(recommendation.place['id']?.toString());
        }).toList();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 16 : 28,
                mobile ? 16 : 24,
                mobile ? 16 : 28,
                36,
              ),
              children: [
                _sectionTitle('קרוב אליך'),
                if (nearby.isEmpty)
                  _emptySection(
                    icon: Icons.near_me_outlined,
                    text: _hasLocation
                        ? 'לא נמצאו כרגע מקומות מתאימים בטווח של 20 ק״מ.'
                        : 'כדי לקבל המלצות באזור שלך, יש לאפשר גישה למיקום.',
                  )
                else
                  ...nearby.take(4).map(_recommendationCard),
                _sectionTitle('מומלץ לפי הטעם שלך'),
                if (personal.isEmpty)
                  _emptySection(
                    icon: Icons.auto_awesome_outlined,
                    text:
                        'ככל שתוסיף ותדרג חוויות, יופיעו כאן המלצות מדויקות יותר.',
                  )
                else
                  ...personal.take(8).map(_recommendationCard),
                _sectionTitle('פופולרי אצל אנשים עם טעם דומה'),
                if (_similarTasteRecommendations.isEmpty)
                  _emptySection(
                    icon: Icons.groups_outlined,
                    text: 'עדיין אין מספיק דירוגים ממשתמשים בעלי טעם דומה.',
                  )
                else
                  ..._similarTasteRecommendations.map(_recommendationCard),
                _sectionTitle('אנשים שאולי תרצה לעקוב אחריהם'),
                if (_similarUsers.isEmpty)
                  _emptySection(
                    icon: Icons.person_search_outlined,
                    text: 'עדיין אין מספיק משתמשים עם היסטוריית חוויות דומה.',
                  )
                else
                  _similarUsersGrid(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 4, 11),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _recommendationCard(_PlaceRecommendation recommendation) {
    final place = <String, dynamic>{
      ...recommendation.place,
      'recommendation_reason': recommendation.reason,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PlaceCard(
        place: place,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaceDetailsScreen(place: place),
            ),
          );
        },
      ),
    );
  }

  Widget _emptySection({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.11),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _similarUsersGrid() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: _similarUsers.map((user) {
        final profile = user.profile;
        final id = profile['id']?.toString() ?? '';
        final displayName = profile['display_name']?.toString().trim();
        final email = profile['email']?.toString().trim();
        final name = displayName?.isNotEmpty == true
            ? displayName!
            : (email?.split('@').first ?? 'משתמש');
        final avatarUrl = profile['avatar_url']?.toString().trim();

        return SizedBox(
          width: 210,
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: id.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(userId: id),
                        ),
                      );
                    },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.champagne.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.surfaceRaised,
                      backgroundImage: avatarUrl?.isNotEmpty == true
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: avatarUrl?.isNotEmpty == true
                          ? null
                          : const Icon(
                              Icons.person_outline,
                              color: AppColors.textMuted,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${(user.similarity * 100).round()}% התאמה בטעם',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.champagneSoft,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PlaceRecommendation {
  final Map<String, dynamic> place;
  final double score;
  final String reason;

  const _PlaceRecommendation({
    required this.place,
    required this.score,
    required this.reason,
  });
}

class _Reason {
  final double weight;
  final String text;

  const _Reason(this.weight, this.text);
}

class _SimilarUser {
  final Map<String, dynamic> profile;
  final double similarity;

  const _SimilarUser({
    required this.profile,
    required this.similarity,
  });
}
