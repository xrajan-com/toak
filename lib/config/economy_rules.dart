// The AUP economy rules this build explains to its players.
//
// Sent to the backend as X-Economy-Rules, which keeps the same number as
// ECONOMY_RULES_VERSION in backend/src/economy/constants.js;
// test/economy_rules_test.dart fails if the two drift apart. The full rules
// are written down in docs/ECONOMY_RULES.md.
//
// Version 2 (build 87): the entry fee is the most a game can cost. Losing,
// leaving the table, and a game interrupted before it finished all cost the
// fee and nothing more. Quick Game is practice and never changes the wallet.
const int economyRulesVersion = 2;
