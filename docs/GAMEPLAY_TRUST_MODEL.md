# Gameplay trust model

Status: accepted for the 550-event release
Model identifier: `authenticated-client-outcome-claims-v1`

## Decision

Ten of a Kind is a local, single-player poker game. For this release, the
registered Firebase account is trusted to report the outcome of a match that
ran on its device. The backend does not attest the cards, player actions,
random-number stream, placement, or win.

The backend remains authoritative for:

- the versioned campaign catalog, entry fees, table sizes, and payouts;
- reservation, commit, refund, recovery, and settlement state transitions;
- wallet balances and caps, campaign clears, statistics, and idempotency;
- account deletion locks and the public leaderboard projection.

A campaign outcome is accepted only for the matching committed entry
reservation. The production legacy-event escape hatch remains disabled.
Rewarded-ad credits remain disabled until provider-side verification exists.

## Product boundary

AUP, titles, campaign clears, and leaderboard positions are entertainment
state. They have no cash value and cannot determine a prize, payout, purchase,
eligibility, moderation decision, access to a real-world benefit, or any other
competitive entitlement. The leaderboard is a cosmetic community display,
not a verified fair-play ranking.

This boundary is mandatory because a modified authenticated client can claim a
winning placement. Firebase Authentication, App Check, rate limiting, catalog
validation, and receipt idempotency can reduce impersonation or abuse, but none
of them proves that gameplay occurred fairly.

## Accepted risks

- A modified client can overstate a local result and accelerate its own AUP,
  campaign progress, statistics, or cosmetic leaderboard position.
- The server can validate accounting consistency but cannot distinguish an
  honest outcome from a fabricated outcome under this model.
- Public leaderboard data must therefore never be represented as audited,
  cheat-proof, or suitable for prize qualification.

These risks are accepted only while the product remains no-money, no-wagering,
and no-prize single-player entertainment.

## Required controls

- Require a registered, revocation-checked Firebase token for shared economy
  mutations.
- Derive fees, payouts, table sizes, and prerequisites from a content-hashed
  server catalog; never accept client-provided values for them.
- Require a committed, catalog-versioned entry reservation before campaign
  settlement.
- Keep settlement idempotent, keep progress arrays bounded, and keep production
  legacy flags off.
- Keep Firestore authoritative collections client-read-only or private.
- Describe the public leaderboard as cosmetic/community data wherever it is
  used outside the game fiction.
- Do not add money, prizes, tradability, purchasable advantage, or external
  eligibility without replacing this model first.

## Upgrade path for verified competition

Any future competitive or valuable outcome requires a new trust-model version
and a server-verifiable match protocol. At minimum it must include a
server-issued one-use match ticket, server-controlled randomness or a committed
seed protocol, an authenticated action transcript, deterministic replay of the
complete hand/tournament rules, timeout and disconnect rules, replay
protection, and an abuse-reviewed retention policy. Device attestation alone is
not sufficient.

The release must fail closed for competitive rewards until that verifier is
implemented and independently tested.
