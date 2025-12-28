import 'dart:async';
import 'package:flutter/material.dart';

/// A banner that cycles through a list of image assets every [interval].
/// By default it fades between them every 2 seconds.
class VenueBanner extends StatefulWidget {
  const VenueBanner({
    super.key,
    required this.assetPaths,
    this.interval = const Duration(seconds: 2),
    this.maxWidth = 420,
    this.aspectRatio = 1000 / 250,
    this.borderRadius = 18,
    this.shadow = true,
  });

  /// The list of asset paths (PNG/WebP/JPG etc) to rotate through.
  final List<String> assetPaths;

  /// How long to display each image.
  final Duration interval;

  /// Maximum width of the banner on screen.
  final double maxWidth;

  /// Aspect ratio (width / height).
  final double aspectRatio;

  /// Rounded corner radius.
  final double borderRadius;

  /// Whether to draw a subtle drop shadow behind it.
  final bool shadow;

  @override
  State<VenueBanner> createState() => _VenueBannerState();
}

class _VenueBannerState extends State<VenueBanner> {
  int _index = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    // Precache images so transitions are smooth
    for (final p in widget.assetPaths) {
      precacheImage(AssetImage(p), context);
    }
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.assetPaths.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      widget.assetPaths[_index],
      key: ValueKey(_index), // important for AnimatedSwitcher
      fit: BoxFit.contain,
    );

    final banner = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: img,
      ),
    );

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: widget.shadow
            ? BoxDecoration(
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    spreadRadius: -2,
                    offset: Offset(0, 4),
                    color: Colors.black54,
                  )
                ],
              )
            : null,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: banner,
        ),
      ),
    );
  }
}