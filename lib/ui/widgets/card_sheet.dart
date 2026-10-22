import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/ui/utils/card_image.dart';

/// Shows a shareable card full size, with Save (to the phone's photos, or a
/// download on the web) and Share. [card] is laid out at 360 x 450 and
/// exported at x3. [onSaved] and [onShared] report what the player did.
Future<void> showCardSheet(
  BuildContext context, {
  required Widget card,
  required String fileStem,
  required String shareText,
  ValueChanged<CardSaveResult>? onSaved,
  VoidCallback? onShared,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => _CardSheet(
      card: card,
      fileStem: fileStem,
      shareText: shareText,
      onSaved: onSaved,
      onShared: onShared,
    ),
  );
}

class _CardSheet extends StatefulWidget {
  final Widget card;
  final String fileStem;
  final String shareText;
  final ValueChanged<CardSaveResult>? onSaved;
  final VoidCallback? onShared;

  const _CardSheet({
    required this.card,
    required this.fileStem,
    required this.shareText,
    this.onSaved,
    this.onShared,
  });

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;
  String? _status;
  bool _statusOk = true;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final png = await captureCardPng(_cardKey);
    final result = png == null
        ? CardSaveResult.failed
        : await saveCardPng(png, fileName: cardFileName(widget.fileStem));
    widget.onSaved?.call(result);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = result.message;
      _statusOk = result.ok;
    });
  }

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final png = await captureCardPng(_cardKey);
    final shared = png != null &&
        await shareCardPng(
          png,
          fileName: cardFileName(widget.fileStem),
          text: widget.shareText,
        );
    if (shared) widget.onShared?.call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!shared) {
        _status = 'Could not open sharing. Try Save instead.';
        _statusOk = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RepaintBoundary(key: _cardKey, child: widget.card),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Close'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('card-save'),
                onPressed: _busy ? null : () => unawaited(_save()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF00B5C8)),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('card-share'),
                onPressed: _busy ? null : () => unawaited(_share()),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2800),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text(
                  'Share',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _status!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusOk
                      ? const Color(0xFF00B5C8)
                      : const Color(0xFFFF2800),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
