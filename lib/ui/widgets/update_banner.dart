import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ten_of_a_kind_poker/services/app_release_service.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

/// A quiet "an update is available" strip with an x.
///
/// Renders nothing at all until the backend says a newer build exists and the
/// player has not already dismissed that build, which is the usual case. It
/// checks in the background and never blocks what is underneath it.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, this.service});

  /// Injectable for tests; production passes nothing.
  final AppReleaseService? service;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  late final AppReleaseService _service =
      widget.service ?? AppReleaseService();

  AppRelease? _pending;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final AppRelease? release = await _service.pendingUpdate();
    if (!mounted || release == null) return;
    setState(() => _pending = release);
  }

  Future<void> _dismiss() async {
    final int? build = _pending?.latestBuild;
    setState(() => _pending = null);
    if (build != null) await _service.dismiss(build);
  }

  Future<void> _openStore() async {
    final String? url = _pending?.storeUrl;
    if (url == null) return;
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the store page'),
          duration: Duration(milliseconds: 900),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppRelease? release = _pending;
    if (release == null) return const SizedBox.shrink();

    final String copy =
        release.message ?? 'A new version of X Poker is available.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Semantics(
          liveRegion: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.55)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.system_update_alt,
                      size: 18, color: AppColors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      copy,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontFamily: 'OpenSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (release.storeUrl != null)
                    TextButton(
                      onPressed: () => unawaited(_openStore()),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'UPDATE',
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => unawaited(_dismiss()),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.white70,
                    tooltip: 'Dismiss',
                    splashRadius: 18,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
