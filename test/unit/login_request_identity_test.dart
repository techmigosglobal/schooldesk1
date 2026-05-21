import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/services/backend_api_client.dart';

void main() {
  test('plain username stays the primary login identity', () {
    expect(
      const LoginRequest(username: 'teacher01', password: 'secret').toJson(),
      {'username': 'teacher01', 'password': 'secret'},
    );
  });

  test('email identity is also sent as fallback email', () {
    expect(
      const LoginRequest(
        username: 'teacher@example.test',
        password: 'secret',
      ).toJson(),
      {
        'username': 'teacher@example.test',
        'email': 'teacher@example.test',
        'password': 'secret',
      },
    );
  });

  test('principal username aliases keep local Docker email fallback', () {
    expect(const LoginRequest(username: 'PRINC', password: 'secret').toJson(), {
      'username': 'PRINC',
      'email': 'principal@schooldesk.local',
      'password': 'secret',
    });
    expect(
      const LoginRequest(username: 'principal', password: 'secret').toJson(),
      {
        'username': 'principal',
        'email': 'principal@schooldesk.local',
        'password': 'secret',
      },
    );
    expect(
      const LoginRequest(
        username: 'principal@schooldesk.com',
        password: 'secret',
      ).toJson(),
      {
        'username': 'principal@schooldesk.com',
        'email': 'principal@schooldesk.local',
        'password': 'secret',
      },
    );
  });
}
