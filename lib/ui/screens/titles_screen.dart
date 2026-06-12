import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class TitlesScreen extends StatelessWidget {
  const TitlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: const Text(
          'Titles',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isGuest
          ? const _GuestEmpty()
          : const _TitlesList(),
    );
  }
}

class _GuestEmpty extends StatelessWidget {
  const _GuestEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          'Nothing to show.\nPlay Career to earn Titles.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 15.5,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class _TitleEntry {
  final VenueGroup group;
  final VenueTheme venue;
  final String titleName;
  const _TitleEntry({
    required this.group,
    required this.venue,
    required this.titleName,
  });
}

class _TitlesList extends StatelessWidget {
  const _TitlesList();

  List<_TitleEntry> _earnedForGroup(
    CampaignProgressService progress,
    VenueGroup group,
    List<VenueTheme> venues,
  ) {
    final out = <_TitleEntry>[];
    for (final v in venues) {
      if (!progress.hasTitle(group: group, kingdomName: v.name)) continue;
      out.add(_TitleEntry(
        group: group,
        venue: v,
        titleName: kingdomTitleFor(group: group, kingdomName: v.name),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<CampaignProgressService>();

    final india = _earnedForGroup(progress, VenueGroup.india, indianVenues);
    final intl =
        _earnedForGroup(progress, VenueGroup.international, internationalVenues);

    final all = [...india, ...intl];
    if (all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            'No titles yet.\nWin a Main Event after clearing every Sub‑Kingdom.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              height: 1.25,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        if (india.isNotEmpty) ...[
          const _SectionHeader(title: 'India'),
          ...india.map((e) => _TitleTile(
                entry: e,
              )),
          const SizedBox(height: 14),
        ],
        if (intl.isNotEmpty) ...[
          const _SectionHeader(title: 'International'),
          ...intl.map((e) => _TitleTile(
                entry: e,
              )),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TitleTile extends StatelessWidget {
  final _TitleEntry entry;
  const _TitleTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final v = entry.venue;
    final border = v.felt.withValues(alpha: 0.9);
    final subtitle = 'Title: ${entry.titleName}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.6),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            v.flagAsset,
            width: 44,
            height: 30,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 44,
              height: 30,
              color: Colors.white12,
              alignment: Alignment.center,
              child: const Icon(Icons.flag_outlined,
                  color: Colors.white54, size: 16),
            ),
          ),
        ),
        title: Text(
          v.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
