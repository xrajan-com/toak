import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'overlays.dart' as go;
import 'players.dart' show Seat; // Seat{name, chips, startChips, busted, about}
import 'models.dart' show truncateNice;

Future<void> showScoreboardSheet(
  BuildContext context,
  List<Seat> seats, {
  Seat? heroSeat,
}) async {
  // Sort: playing first, then chips desc; busted at bottom
  final sorted = [...seats]..sort((a, b) {
      final ax = a.busted ? 0 : 1;
      final bx = b.busted ? 0 : 1;
      if (ax != bx) return bx.compareTo(ax);
      return b.chips.compareTo(a.chips);
    });

  int? maxChips;
  for (final s in seats) {
    if (s.busted) continue;
    if (maxChips == null || s.chips > maxChips) {
      maxChips = s.chips;
    }
  }
  final Set<Seat> leaders = <Seat>{};
  if (maxChips != null) {
    for (final s in seats) {
      if (!s.busted && s.chips == maxChips) {
        leaders.add(s);
      }
    }
  }

  bool isHero(Seat s) {
    try {
      return (s as dynamic).isHero == true;
    } catch (_) {
      return false;
    }
  }

  Color nameColor(Seat s) {
    if (s.busted) return const Color(0xFFFF5567);
    if (isHero(s)) return Colors.white;
    return const Color(0xFFFFD76E);
  }

  Color chipColor(Seat s) {
    if (s.busted || s.chips <= 0) return const Color(0xFFFF5C6C);
    if (leaders.contains(s)) return const Color(0xFF24B6FF);
    if (s.chips > s.startChips) return const Color(0xFF4CFFBE);
    if (s.shortStack) return const Color(0xFFFF5C6C);
    if (s.chips < s.startChips) return const Color(0xFFFFD76E);
    return Colors.white;
  }

  String flagForKingdom(String kingdomRaw) {
    final k = kingdomRaw.toLowerCase().trim();
    if (k.isEmpty) return '';
    const flags = {
      // Indian circuit
      'baroda': 'assets/images/flags/baroda.png',
      'hyderabad': 'assets/images/flags/hyderabad.png',
      'indore': 'assets/images/flags/indore.png',
      'jaipur': 'assets/images/flags/jaipur.png',
      'maratha empire': 'assets/images/flags/maratha_empire.png',
      'mysore': 'assets/images/flags/mysore.png',
      'new delhi': 'assets/images/flags/new_delhi.png',
      'sikh empire': 'assets/images/flags/sikh_empire.png',
      'sikkim': 'assets/images/flags/sikkim.png',
      'travancore': 'assets/images/flags/travancore.png',
      // International circuit
      'africa': 'assets/images/flags/africa.png',
      'amazon': 'assets/images/flags/amazon.png',
      's. america': 'assets/images/flags/amazon.png',
      'south america': 'assets/images/flags/amazon.png',
      'america': 'assets/images/flags/america.png',
      'n. america': 'assets/images/flags/america.png',
      'north america': 'assets/images/flags/america.png',
      'arabia': 'assets/images/flags/arabia.png',
      'australia': 'assets/images/flags/australia.png',
      'china': 'assets/images/flags/china.png',
      'europe': 'assets/images/flags/europe.png',
      'india': 'assets/images/flags/india.png',
      'russia': 'assets/images/flags/russia.png',
      'asia': 'assets/images/flags/asean.png',
      'southeast': 'assets/images/flags/asean.png',
      // Euro circuit
      'britain': 'assets/images/flags/euro/britain.png',
      'france': 'assets/images/flags/euro/france.png',
      'italy': 'assets/images/flags/euro/italy.png',
      'spain': 'assets/images/flags/euro/spain.png',
      'portugal': 'assets/images/flags/euro/portugal.png',
      'north sea': 'assets/images/flags/euro/north_sea.png',
      'scandinavia': 'assets/images/flags/euro/scandinavia.png',
      'baltic marches': 'assets/images/flags/euro/baltic_marches.png',
      'russia & siberia': 'assets/images/flags/euro/russia_siberia.png',
      'russia and siberia': 'assets/images/flags/euro/russia_siberia.png',
      'mediterranean': 'assets/images/flags/euro/mediterranean.png',
      // Oceania circuit
      'alaska': 'assets/images/flags/oceania/alaska.png',
      'caribbean': 'assets/images/flags/oceania/caribbean.png',
      'dragonland': 'assets/images/flags/oceania/dragonland.png',
      'straits': 'assets/images/flags/oceania/straits.png',
      'indian ocean': 'assets/images/flags/oceania/indian_ocean.png',
      'pacific': 'assets/images/flags/oceania/pacific.png',
      'british isles': 'assets/images/flags/oceania/british_isles.png',
      'french isles': 'assets/images/flags/oceania/french_isles.png',
      'dutch isles': 'assets/images/flags/oceania/dutch_isles.png',
      'american isles': 'assets/images/flags/oceania/american_isles.png',
      'dominion of canada': 'assets/images/flags/us/canada.png',
      'massachusetts': 'assets/images/flags/us/massachusetts.png',
      'new york': 'assets/images/flags/us/new_york.png',
      'virginia': 'assets/images/flags/us/virginia.png',
      'illinois': 'assets/images/flags/us/illinois.png',
      'florida': 'assets/images/flags/us/florida.png',
      'texas': 'assets/images/flags/us/texas.png',
      'kansas': 'assets/images/flags/us/kansas.png',
      'colorado': 'assets/images/flags/us/colorado.png',
      'california': 'assets/images/flags/us/california.png',
    };
    return flags[k] ?? '';
  }

  Color auraColor(int aura) {
    if (aura >= 90) return const Color(0xFFFFF4C2);
    if (aura >= 75) return const Color(0xFF64FFDA);
    if (aura > 60) return const Color(0xFF81D4FA);
    return const Color(0xFFFF8A80);
  }

  Widget auraBadge(int aura) {
    final Color border = auraColor(aura);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.9), width: 1),
        color: border.withValues(alpha: 0.12),
      ),
      child: Text(
        'Aura $aura',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    isScrollControlled: true,
    builder: (_) {
      return SafeArea(
        child: Builder(
          builder: (sheetContext) {
            final media = MediaQuery.of(sheetContext);
            final maxListHeight =
                (media.size.height * 0.65).clamp(360.0, 780.0);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(sheetContext).pop(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, media.viewInsets.bottom + 24),
                child: DecoratedBox(
                  decoration:
                      go.renoirGlassPanelDecoration(radius: 18, opacity: 0.68),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Center(
                          child: go.GoldenText(
                            'Scoreboard',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxListHeight,
                            maxWidth: 760,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: sorted.length,
                            separatorBuilder: (_, __) => const Divider(
                                color: Colors.white12, height: 10),
                            itemBuilder: (_, i) {
                              final s = sorted[i];
                              final kingdom = s.kingdom.trim();
                              final about = s.about.trim();
                              final aboutDisplay = about.isNotEmpty
                                  ? truncateNice(about, 40)
                                  : '—';
                              final Color accentColor = go.feltColorForKingdom(
                                kingdom.isNotEmpty ? kingdom : null,
                              );
                              final String chipsLabel = '${s.chips}';
                              final String flagPath = flagForKingdom(kingdom);
                              final bool hero = isHero(s);
                              final bool busted = s.busted;

                              return Container(
                                decoration: BoxDecoration(
                                  color: hero
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : busted
                                          ? Colors.black.withValues(alpha: 0.28)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 3, horizontal: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _FlagTile(flagPath: flagPath, name: s.name),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 4,
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: s.name,
                                              style: TextStyle(
                                                color: nameColor(s).withValues(
                                                    alpha: busted ? 0.42 : 1.0),
                                                fontWeight: hero
                                                    ? FontWeight.w900
                                                    : FontWeight.w700,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            if (kingdom.isNotEmpty)
                                              TextSpan(
                                                text: ' ($kingdom)',
                                                style: TextStyle(
                                                  color: accentColor.withValues(
                                                      alpha:
                                                          busted ? 0.28 : 1.0),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  height: 1.05,
                                                ),
                                              ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    auraBadge(s.aura),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        chipsLabel,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: chipColor(s).withValues(
                                              alpha: busted ? 0.35 : 1.0),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        aboutDisplay,
                                        textAlign: TextAlign.right,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12.5,
                                          height: 1.05,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial =
        (name.isNotEmpty ? name.characters.first : '?').toUpperCase();
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({required this.flagPath, required this.name});
  final String flagPath;
  final String name;

  @override
  Widget build(BuildContext context) {
    const double w = 36;
    const double h = 24;
    final fallback = _InitialAvatar(name: name);
    if (flagPath.isEmpty) return SizedBox(width: w, height: h, child: fallback);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: w,
        height: h,
        child: Image.asset(
          flagPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

String _formatStack(int amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount.toString();
}
