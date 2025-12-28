import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual states a bot avatar can animate through.
enum AvatarMood {
  idle,
  focused,
  raise,
  win,
  lose,
  folded,
  busted,
}

/// Square avatar widget.
///
/// Uses a deterministic asset path: `<assetFolder>/<avatarKey>.png`.
class BotAvatar extends StatelessWidget {
  const BotAvatar({
    super.key,
    required this.avatarKey,
    required this.mood,
    this.assetFolder,
    this.size,
    this.fallbackAsset,
    this.idleInterval = const Duration(milliseconds: 900),
    this.actionInterval = const Duration(milliseconds: 260),
    this.overlayBuilder,
  });

  /// Slug used to lookup assets under `assets/bots/<avatarKey>/`.
  final String avatarKey;

  /// Current mood (determines which frame bundle to play).
  final AvatarMood mood;
  final String? assetFolder;

  /// Optional explicit size. When null, expands to parent constraints.
  final double? size;

  /// Optional fallback asset when specific mood frames are missing.
  final String? fallbackAsset;

  /// Frame cadence for idle/breathing loops.
  final Duration idleInterval;

  /// Frame cadence for energetic loops (raise / win / lose).
  final Duration actionInterval;

  /// Optional overlay (e.g., tinted filters) supplied by parent.
  final Widget Function(BuildContext context, AvatarMood mood)? overlayBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = size ??
            (constraints.hasBoundedWidth && constraints.hasBoundedHeight
                ? math.min(constraints.maxWidth, constraints.maxHeight)
                : constraints.biggest.shortestSide);

        final double dimension =
            side.isFinite && side > 0 ? side : (size ?? 200.0);

        final String? assetKey = _avatarAssetKey(
          avatarKey: avatarKey,
          assetFolder: assetFolder,
        );

        final Widget fallback = _FallbackAvatar(
          avatarKey: avatarKey,
          mood: mood,
          fallbackAsset: fallbackAsset,
          dimension: dimension,
        );

        Widget content = assetKey == null
            ? fallback
            : SizedBox.square(
                dimension: dimension,
                child: Image.asset(
                  assetKey,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => fallback,
                ),
              );

        if (overlayBuilder != null) {
          content = Stack(
            fit: StackFit.expand,
            children: [
              content,
              overlayBuilder!(context, mood),
            ],
          );
        }

        if (size != null) {
          return SizedBox.square(dimension: size, child: content);
        }
        return SizedBox.square(dimension: dimension, child: content);
      },
    );
  }

  static String? _avatarAssetKey({
    required String avatarKey,
    required String? assetFolder,
  }) {
    final String folder = (assetFolder ?? '').trim();
    if (folder.isEmpty) return null;

    final String key = avatarKey.trim();
    if (key.isEmpty) return null;

    final String normalized = folder.endsWith('/') ? folder : '$folder/';
    return '$normalized$key.png';
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({
    required this.avatarKey,
    required this.mood,
    required this.dimension,
    this.fallbackAsset,
  });

  final String avatarKey;
  final AvatarMood mood;
  final double dimension;
  final String? fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final Color tint;
    switch (mood) {
      case AvatarMood.idle:
      case AvatarMood.folded:
        tint = Colors.blueGrey.shade700;
        break;
      case AvatarMood.focused:
      case AvatarMood.raise:
        tint = Colors.deepOrange.shade400;
        break;
      case AvatarMood.win:
        tint = Colors.greenAccent.shade400;
        break;
      case AvatarMood.lose:
        tint = Colors.redAccent.shade400;
        break;
      case AvatarMood.busted:
        tint = Colors.grey.shade800;
        break;
    }

    Widget child;
    if (fallbackAsset != null && fallbackAsset!.isNotEmpty) {
      child = Image.asset(
        fallbackAsset!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            _PlaceholderBlock(avatarKey: avatarKey, tint: tint),
      );
    } else {
      child = _PlaceholderBlock(avatarKey: avatarKey, tint: tint);
    }

    return SizedBox.square(dimension: dimension, child: child);
  }
}

class _PlaceholderBlock extends StatelessWidget {
  const _PlaceholderBlock({required this.avatarKey, required this.tint});

  final String avatarKey;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tint,
      alignment: Alignment.center,
      child: Text(
        avatarKey.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
