import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:horizon_app/services/pocketbase_service.dart';

void main() {
  test('errors read as plain language', () {
    expect(friendlyError(ClientException(statusCode: 0)), contains('No internet'));
    expect(friendlyError(ClientException(statusCode: 530)), contains('server is offline')); // Cloudflare: tunnel down
    expect(friendlyError(ClientException(statusCode: 502)), contains('server is offline'));
    expect(friendlyError(ClientException(statusCode: 401)), contains('login has expired'));
    expect(friendlyError(ClientException(statusCode: 400, response: {'message': 'Only 2 available.'})),
        'Only 2 available.');
    expect(friendlyError(Exception('boom')), 'Something went wrong. Please try again.');
  });
}
