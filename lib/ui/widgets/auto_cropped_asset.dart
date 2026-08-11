import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Caches cropped PNG bytes per asset for reuse.
class _CroppedCache {
  static final Map<String, Uint8List> _png = {};
  static Uint8List? get(String key) => _png[key];
  static void set(String key, Uint8List bytes) => _png[key] = bytes;
}

/// Heuristic auto-crop for “white lip” borders around card images.
/// - Scans from all four edges until it sees a non-(near-)white pixel,
///   giving you a border thickness in each direction.
/// - Applies safety limits so we never crop too much.
Future<Uint8List> _cropWhiteBorderPng(
  Uint8List originalBytes, {
  int whiteThreshold = 246, // 0..255: > means treated as “white-ish”
  int alphaThreshold = 8, // 0..255: <= transparent-ish
  double maxCropFraction = 0.18, // never crop more than 18% per side
  double minCropFraction = 0.01, // never crop less than 1% (guards tiny noise)
}) async {
  // Decode to an image
  final codec = await ui.instantiateImageCodec(originalBytes);
  final frame = await codec.getNextFrame();
  final ui.Image img = frame.image;

  final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    // Fallback: return original if platform can’t give raw pixels.
    return originalBytes;
  }

  final w = img.width, h = img.height;
  final pixels = byteData.buffer.asUint8List();

  bool isWhiteish(int x, int y) {
    final i = (y * w + x) * 4;
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    final a = pixels[i + 3];
    if (a <= alphaThreshold) return true; // treat transparent as background
    return (r >= whiteThreshold && g >= whiteThreshold && b >= whiteThreshold);
  }

  // Scan from edges to find first non-white-ish pixel.
  int left = 0, right = w - 1, top = 0, bottom = h - 1;

  // LEFT
  while (left < w) {
    bool allWhite = true;
    for (int y = 0; y < h; y += 3) {
      // step 3 for speed
      if (!isWhiteish(left, y)) {
        allWhite = false;
        break;
      }
    }
    if (!allWhite) break;
    left++;
  }

  // RIGHT
  while (right >= 0) {
    bool allWhite = true;
    for (int y = 0; y < h; y += 3) {
      if (!isWhiteish(right, y)) {
        allWhite = false;
        break;
      }
    }
    if (!allWhite) break;
    right--;
  }

  // TOP
  while (top < h) {
    bool allWhite = true;
    for (int x = 0; x < w; x += 3) {
      if (!isWhiteish(x, top)) {
        allWhite = false;
        break;
      }
    }
    if (!allWhite) break;
    top++;
  }

  // BOTTOM
  while (bottom >= 0) {
    bool allWhite = true;
    for (int x = 0; x < w; x += 3) {
      if (!isWhiteish(x, bottom)) {
        allWhite = false;
        break;
      }
    }
    if (!allWhite) break;
    bottom--;
  }

  // Convert edge positions to thickness (in pixels)
  int leftCrop = left.clamp(0, w ~/ 2);
  int rightCrop = (w - 1 - right).clamp(0, w ~/ 2);
  int topCrop = top.clamp(0, h ~/ 2);
  int bottomCrop = (h - 1 - bottom).clamp(0, h ~/ 2);

  // Safety rails: clamp to sensible min/max fractions
  int clampFrac(int px, int size) {
    final minPx = (size * minCropFraction).round();
    final maxPx = (size * maxCropFraction).round();
    return px.clamp(minPx, maxPx);
  }

  leftCrop = clampFrac(leftCrop, w);
  rightCrop = clampFrac(rightCrop, w);
  topCrop = clampFrac(topCrop, h);
  bottomCrop = clampFrac(bottomCrop, h);

  // If the detector failed (e.g., pure-white card with no graphics near edges),
  // ensure we still crop *something* small (minCropFraction) but not too much.
  final newW = (w - leftCrop - rightCrop).clamp(1, w);
  final newH = (h - topCrop - bottomCrop).clamp(1, h);

  // Draw cropped rect into a new image using Canvas to keep it fast & safe.
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();
  final src = Rect.fromLTWH(
    leftCrop.toDouble(),
    topCrop.toDouble(),
    newW.toDouble(),
    newH.toDouble(),
  );
  final dst = Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble());
  canvas.drawImageRect(img, src, dst, paint);
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(newW, newH);
  final croppedBytes = await cropped.toByteData(format: ui.ImageByteFormat.png);

  return croppedBytes?.buffer.asUint8List() ?? originalBytes;
}

/// Widget that displays a card asset with its outer white border auto-cropped.
/// Result is cached in memory for subsequent builds.
class AutoCroppedAsset extends StatefulWidget {
  const AutoCroppedAsset({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fit = BoxFit.cover,
    this.cacheKeySuffix = '',
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  /// If you tweak thresholds in code and want a fresh cache, change this.
  final String cacheKeySuffix;

  @override
  State<AutoCroppedAsset> createState() => _AutoCroppedAssetState();
}

class _AutoCroppedAssetState extends State<AutoCroppedAsset> {
  Uint8List? _png;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AutoCroppedAsset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.cacheKeySuffix != widget.cacheKeySuffix) {
      _png = null;
      _load();
    }
  }

  Future<void> _load() async {
    final cacheKey = '${widget.assetPath}#${widget.cacheKeySuffix}';
    final cached = _CroppedCache.get(cacheKey);
    if (mounted && cached != null) {
      setState(() => _png = cached);
      return;
    }

    final data = await rootBundle.load(widget.assetPath);
    final bytes = data.buffer.asUint8List();

    final cropped = await _cropWhiteBorderPng(bytes);
    _CroppedCache.set(cacheKey, cropped);

    if (!mounted) return;
    setState(() => _png = cropped);
  }

  @override
  Widget build(BuildContext context) {
    final child = (_png == null)
        ? const SizedBox.shrink()
        : Image.memory(_png!, fit: widget.fit, gaplessPlayback: true);

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: child,
      ),
    );
  }
}
