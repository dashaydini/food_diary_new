/// Shared image settings used before files are uploaded to Supabase Storage.
///
/// `image_picker` performs the resize on-device (and through a browser canvas
/// on web), so the original full-resolution photo is never uploaded.
abstract final class ImageUploadPolicy {
  /// Regular photos: experiences, places, galleries and coupons.
  static const double photoMaxDimension = 1280;
  static const int photoQuality = 72;

  /// Menu photos keep a little more detail so small text remains readable.
  static const double menuMaxDimension = 1600;
  static const int menuQuality = 78;

  /// Avatars are displayed at a small size and can be reduced further.
  static const double avatarMaxDimension = 640;
  static const int avatarQuality = 72;
}
