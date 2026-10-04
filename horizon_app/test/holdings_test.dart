import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:horizon_app/services/pocketbase_service.dart';

RecordModel log(String item, String action, int qty) =>
    RecordModel.fromJson({'item': item, 'action': action, 'quantity': qty});

void main() {
  test('old over-returns never become credit', () {
    // Real case from production: an admin "returned" 33 esp32 nobody had out, then took 1.
    final logs = [
      log('esp32', 'Returned', 33),
      log('esp32', 'Checked Out', 1),
      log('led', 'Checked Out', 10),
      log('led', 'Returned', 5),
      log('led', 'Returned Damaged', 5),
      log('mpu', 'Checked Out', 4),
      log('mpu', 'Damaged', 1), // shelf damage report: doesn't change what you hold
    ];
    expect(holdings(logs), {'esp32': 1, 'led': 0, 'mpu': 4});
  });
}
