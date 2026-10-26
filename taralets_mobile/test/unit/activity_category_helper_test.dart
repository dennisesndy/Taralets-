import 'package:flutter_test/flutter_test.dart';
import 'package:taralets_mobile/core/utils/activity_category_helper.dart';

void main() {
  test('legacy Cafe preference is normalized and deduplicated for trip save', () {
    expect(
      normalizeActivityCategories([
        'Cafe',
        'Cafes',
        'Historical / Tourist Site',
      ]),
      ['Cafes', 'Historical / Tourist Site'],
    );
  });
}
