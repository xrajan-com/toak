import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Turning a shareable card on screen into an image, then sharing it or
/// saving it to the device. Used by the hand card and the win cards.

/// The album saved cards go into on the phone.
const String kCardAlbum = 'X Poker';

/// Renders the [RepaintBoundary] under [key] as a PNG. Cards are laid out
/// at 360 x 450, so the default ratio gives 1080 x 1350 (Instagram's
/// portrait size). Null if the card is not on screen.
Future<Uint8List?> captureCardPng(
  GlobalKey key, {
  double pixelRatio = 3.0,
}) async {
  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } catch (error) {
    debugPrint('Card capture failed: $error');
    return null;
  }
}

/// Opens the system share sheet with [png]. False if it could not open.
Future<bool> shareCardPng(
  Uint8List png, {
  required String fileName,
  required String text,
}) async {
  try {
    await Share.shareXFiles(
      <XFile>[XFile.fromData(png, mimeType: 'image/png', name: fileName)],
      text: text,
    );
    return true;
  } catch (error) {
    debugPrint('Card share failed: $error');
    return false;
  }
}

enum CardSaveResult {
  /// In the phone's photos, in the X Poker album.
  savedToPhotos,

  /// Downloaded by the browser.
  downloaded,

  /// The player said no to photo access.
  denied,

  /// This platform cannot save straight to photos; Share can.
  unsupported,

  failed,
}

extension CardSaveResultMessage on CardSaveResult {
  /// What to tell the player after a save.
  String get message => switch (this) {
        CardSaveResult.savedToPhotos => 'Saved to your photos ($kCardAlbum).',
        CardSaveResult.downloaded => 'Saved to your downloads.',
        CardSaveResult.denied =>
          'Photo access is off. Allow it in Settings to save cards.',
        CardSaveResult.unsupported =>
          'Saving is not available here. Use Share to keep it.',
        CardSaveResult.failed => 'Could not save the card. Try again.',
      };

  bool get ok =>
      this == CardSaveResult.savedToPhotos ||
      this == CardSaveResult.downloaded;
}

/// Saves [png] to the device: the photo library on Android and iOS, a
/// download in the browser. [fileName] should end in .png.
Future<CardSaveResult> saveCardPng(
  Uint8List png, {
  required String fileName,
}) async {
  if (kIsWeb) {
    try {
      await XFile.fromData(png, mimeType: 'image/png', name: fileName)
          .saveTo(fileName);
      return CardSaveResult.downloaded;
    } catch (error) {
      debugPrint('Card download failed: $error');
      return CardSaveResult.failed;
    }
  }
  final platform = defaultTargetPlatform;
  if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
    return CardSaveResult.unsupported;
  }
  try {
    if (!await Gal.hasAccess(toAlbum: true) &&
        !await Gal.requestAccess(toAlbum: true)) {
      return CardSaveResult.denied;
    }
    final name = fileName.toLowerCase().endsWith('.png')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    await Gal.putImageBytes(png, album: kCardAlbum, name: name);
    return CardSaveResult.savedToPhotos;
  } on GalException catch (error) {
    debugPrint('Card save failed: $error');
    try {
      if (!await Gal.hasAccess(toAlbum: true)) return CardSaveResult.denied;
    } catch (_) {}
    return CardSaveResult.failed;
  } catch (error) {
    debugPrint('Card save failed: $error');
    return CardSaveResult.failed;
  }
}

/// A file name for a saved card: `x-poker-<what>-<yyyymmdd-hhmmss>.png`.
String cardFileName(String what, {DateTime? at}) {
  final t = at ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final slug = what
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final stamp = '${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  return 'x-poker-${slug.isEmpty ? 'card' : slug}-$stamp.png';
}
