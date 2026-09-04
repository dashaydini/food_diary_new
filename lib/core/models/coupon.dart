class Coupon {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String code;
  final DateTime validUntil;
  final String businessName;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String imageUrl;
  final List<String> galleryImages;
  final List<String> categoryIds;
  final String? notificationRegion;
  final bool isUnlimited;
  final bool isPublished;

  const Coupon({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.code,
    required this.validUntil,
    required this.businessName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    required this.imageUrl,
    this.galleryImages = const [],
    this.categoryIds = const [],
    this.notificationRegion,
    required this.isUnlimited,
    required this.isPublished,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: json['id'].toString(),
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        validUntil: DateTime.parse(json['valid_until'].toString()),
        businessName: json['business_name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        placeId: json['place_id']?.toString(),
        imageUrl: json['image_url']?.toString() ?? '',
        galleryImages: (json['gallery_images'] as List? ?? const [])
            .map((image) => image.toString())
            .where((image) => image.isNotEmpty)
            .toList(),
        categoryIds: (json['category_ids'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        notificationRegion: json['notification_region']?.toString(),
        isUnlimited: json['is_unlimited'] != false,
        isPublished: json['is_published'] == true,
      );

  List<String> get images => galleryImages.isEmpty
      ? (imageUrl.isEmpty ? const [] : [imageUrl])
      : galleryImages;

  String get validUntilLabel =>
      '${validUntil.day.toString().padLeft(2, '0')}.${validUntil.month.toString().padLeft(2, '0')}.${validUntil.year}';

  Map<String, dynamic> get navigationPlace => {
        'name': businessName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
}
