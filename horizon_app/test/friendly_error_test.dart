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
    // A field's own reason beats the generic "Failed to create record."
    expect(
        friendlyError(ClientException(statusCode: 400, response: {
          'message': 'Failed to create record.',
          'data': {'photo': {'code': 'validation_invalid_mime_type', 'message': 'mime type must be one of: image/jpeg'}},
        })),
        'mime type must be one of: image/jpeg');
    expect(friendlyError(ClientException(statusCode: 403, response: {'message': 'Only admins can restock.'})),
        'Only admins can restock.');
  });
}
