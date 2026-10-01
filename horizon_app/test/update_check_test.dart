import 'package:flutter_test/flutter_test.dart';
import 'package:horizon_app/update_check.dart';

void main() {
  test('version comparison', () {
    expect(isNewer('v1.2.0', '1.1.0'), isTrue);
    expect(isNewer('v1.10.0', '1.9.9'), isTrue); // numeric, not alphabetical
    expect(isNewer('v2.0', '1.9.9'), isTrue);
    expect(isNewer('v1.1.0', '1.1.0'), isFalse);
    expect(isNewer('v1.0.9', '1.1.0'), isFalse);
    expect(isNewer('garbage', '1.1.0'), isFalse);
  });
}
