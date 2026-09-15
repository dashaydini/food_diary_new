import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/utils/supabase_image_url.dart';

void main() {
  test('builds a resized public Supabase image URL', () {
    final result = optimizedSupabaseImageUrl(
      'https://demo.supabase.co/storage/v1/object/public/place-images/u/a.jpg?v=7',
      width: 360,
      height: 240,
    );

    final uri = Uri.parse(result);
    expect(uri.path, '/storage/v1/render/image/public/place-images/u/a.jpg');
    expect(uri.queryParameters['v'], '7');
    expect(uri.queryParameters['width'], '360');
    expect(uri.queryParameters['height'], '240');
    expect(uri.queryParameters['quality'], '72');
    expect(uri.queryParameters['resize'], 'cover');
  });

  test('does not change assets, blobs or PDFs', () {
    expect(
      optimizedSupabaseImageUrl('assets/example.jpg', width: 200),
      'assets/example.jpg',
    );
    expect(
      optimizedSupabaseImageUrl('blob:https://example.test/id', width: 200),
      'blob:https://example.test/id',
    );
    const pdf =
        'https://demo.supabase.co/storage/v1/object/public/menus/menu.pdf';
    expect(optimizedSupabaseImageUrl(pdf, width: 200), pdf);
  });
}
