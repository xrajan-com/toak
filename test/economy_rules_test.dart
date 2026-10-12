import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ten_of_a_kind_poker/config/economy_rules.dart';
import 'package:ten_of_a_kind_poker/services/api_client.dart';
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';

void main() {
  test('the app and the backend agree on the economy rules version', () {
    final source =
        File('backend/src/economy/constants.js').readAsStringSync();
    final match =
        RegExp(r'const ECONOMY_RULES_VERSION = (\d+);').firstMatch(source);

    expect(match, isNotNull,
        reason: 'ECONOMY_RULES_VERSION not found in constants.js');
    expect(int.parse(match!.group(1)!), economyRulesVersion);
  });

  test('every economy request tells the backend which rules it explains',
      () async {
    late http.Request seen;
    final service = EconomyApiService(
      apiClient: ApiClient(
        baseUrl: 'https://backend.test',
        tokenProvider: (_) async => 'test-token',
        httpClient: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'accepted': true,
              'duplicate': false,
              'reason': 'abandoned_entry_forfeited',
              'delta': 0,
            }),
            200,
          );
        }),
      ),
    );

    await service.recoverCommittedEntry(attemptId: 'entry:1');

    expect(seen.url.path, '/v1/economy/entries/recover');
    expect(seen.headers['X-Economy-Rules'], '$economyRulesVersion');
  });
}
