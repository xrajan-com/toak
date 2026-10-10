import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ten_of_a_kind_poker/services/api_client.dart';
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';

EconomyApiService _serviceReplying(int status, Object body,
    {void Function(http.Request request)? onRequest}) {
  return EconomyApiService(
    apiClient: ApiClient(
      baseUrl: 'https://backend.test',
      tokenProvider: (_) async => 'test-token',
      httpClient: MockClient((request) async {
        onRequest?.call(request);
        return http.Response(jsonEncode(body), status);
      }),
    ),
  );
}

void main() {
  test('rank() asks the server for the signed-in player\'s rank', () async {
    late http.Request seen;
    final service = _serviceReplying(
      200,
      {'ok': true, 'totalAup': 284340, 'rank': 12, 'rankedPlayers': 340},
      onRequest: (request) => seen = request,
    );

    final standing = await service.rank();

    expect(seen.method, 'GET');
    expect(seen.url.path, '/v1/economy/rank');
    expect(seen.headers['Authorization'], 'Bearer test-token');
    expect(standing.totalAup, 284340);
    expect(standing.rank, 12);
    expect(standing.rankedPlayers, 340);
    expect(standing.isRanked, isTrue);
  });

  test('a player without AUP is unranked', () async {
    final service = _serviceReplying(
      200,
      {'ok': true, 'totalAup': 0, 'rank': null, 'rankedPlayers': 340},
    );

    final standing = await service.rank();

    expect(standing.isRanked, isFalse);
    expect(standing.rank, isNull);
    expect(standing.rankedPlayers, 340);
  });

  test('guests are refused with an unauthenticated error', () async {
    final service = _serviceReplying(
      403,
      {'code': 'registered_account_required', 'error': 'Register first.'},
    );

    expect(
      service.rank(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiFailureKind.unauthenticated)
            .having((e) => e.code, 'code', 'registered_account_required'),
      ),
    );
  });

  test('a malformed reply is an error, not rank #0', () async {
    final service = _serviceReplying(200, {'rank': 3});

    expect(
      service.rank(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiFailureKind.malformedResponse),
      ),
    );
  });

  test('parsing never shows a rank below the player count or a negative', () {
    final standing = EconomyRank.fromJson(
      {'ok': true, 'totalAup': 500, 'rank': 7, 'rankedPlayers': 3},
    );
    expect(standing.rank, 7);
    expect(standing.rankedPlayers, 7);

    final odd = EconomyRank.fromJson(
      {'ok': true, 'totalAup': -5, 'rank': 2, 'rankedPlayers': -1},
    );
    expect(odd.totalAup, 0);
    expect(odd.rank, isNull);
    expect(odd.rankedPlayers, 0);
  });
}
