import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/utils/supabase_image_url.dart';

void main() {
  test('keeps a public Supabase object URL directly loadable', () {
    const source =
        'https://demo.supabase.co/storage/v1/object/public/place-images/u/a.jpg?v=7';
    final result = optimizedSupabaseImageUrl(
      source,
      width: 360,
      height: 240,
    );

    expect(result, source);
  });

  test('recovers a legacy transformed URL as its public object URL', () {
    final result = optimizedSupabaseImageUrl(
      'https://demo.supabase.co/storage/v1/render/image/public/place-images/u/a.jpg?v=7&width=360&height=240&quality=72&resize=cover',
      width: 360,
      height: 240,
    );

    expect(
      result,
      'https://demo.supabase.co/storage/v1/object/public/place-images/u/a.jpg?v=7',
    );
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
