import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';

void main() {
  test('leaderboard Aura values are capped at 100 Aura', () {
    const entry = LeaderboardEntry(
      uid: 'player-1',
      displayName: 'Player One',
      auraMilli: 250000,
      totalAup: 2500000000,
      activityScore: 100,
    );

    expect(
      entry.cappedAuraMilli,
      aup.kAupMaxAuraTotal * aup.kAuraMilliPerAura,
    );
    expect(entry.aura, 100);
  });

  test('public REST leaderboard decodes Firestore values for web', () async {
    late Uri requestedUri;
    final service = LeaderboardFirestoreService(
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'documents': [
              {
                'name': 'projects/test/databases/(default)/documents/'
                    'leaderboard/lb1_public',
                'fields': {
                  'displayName': {'stringValue': 'Test Player'},
                  'auraMilli': {'integerValue': '284'},
                  'totalAup': {'integerValue': '2843400'},
                  'activityScore': {'integerValue': '7'},
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final entries = await service.fetchTop10FromPublicRestForTesting();

    expect(requestedUri.host, 'firestore.googleapis.com');
    expect(requestedUri.queryParameters['orderBy'], 'auraMilli desc');
    expect(entries, hasLength(1));
    expect(entries.single.uid, 'lb1_public');
    expect(entries.single.displayName, 'Test Player');
    expect(entries.single.auraMilli, 284);
    expect(entries.single.totalAup, 2843400);
    expect(entries.single.activityScore, 7);
  });
}
