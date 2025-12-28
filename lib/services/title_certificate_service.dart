import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TitleCertificateService {
  static const String _renoirAsset = 'assets/images/renoir_tux.png';

  static String certificateIdFor({
    required String playerId,
    required String kingdomName,
    required String titleName,
    DateTime? issuedAt,
  }) {
    final at = issuedAt ?? DateTime.now();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(at.toUtc());
    final base =
        '${playerId.trim()}|${kingdomName.trim()}|${titleName.trim()}|$stamp';
    final hash = _fnv1a32(base).toRadixString(16).padLeft(8, '0');
    return 'TOK-$stamp-$hash';
  }

  static Future<Uint8List> buildTitleCertificatePdf({
    required String playerName,
    required String playerId,
    required String kingdomName,
    required String titleName,
    DateTime? issuedAt,
    String? certificateId,
  }) async {
    final DateTime at = issuedAt ?? DateTime.now();
    final String certId = certificateId ??
        certificateIdFor(
          playerId: playerId,
          kingdomName: kingdomName,
          titleName: titleName,
          issuedAt: at,
        );

    Uint8List? renoirBytes;
    try {
      final b = await rootBundle.load(_renoirAsset);
      renoirBytes = b.buffer.asUint8List();
    } catch (_) {
      renoirBytes = null;
    }

    final doc = pw.Document();
    final df = DateFormat('dd MMM yyyy');
    final issuedLabel = df.format(at);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.black, width: 2.2),
            ),
            padding: const pw.EdgeInsets.all(28),
            child: pw.Stack(
              children: [
                if (renoirBytes != null)
                  pw.Positioned.fill(
                    child: pw.Opacity(
                      opacity: 0.06,
                      child: pw.Center(
                        child: pw.Image(
                          pw.MemoryImage(renoirBytes),
                          width: 340,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'TEN OF A KIND',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'CERTIFICATE OF TITLE',
                      style: pw.TextStyle(
                        fontSize: 34,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFFFF2800),
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 22),
                    pw.Text(
                      'This certifies that',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      playerName.trim().isEmpty ? 'Player' : playerName.trim(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 38,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'has earned the title of',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      titleName.trim().isEmpty ? 'Champion' : titleName.trim(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'in the Kingdom of ${kingdomName.trim().isEmpty ? '—' : kingdomName.trim()}.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Container(
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(
                            color: PdfColors.grey700,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const pw.EdgeInsets.only(top: 12),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Issued: $issuedLabel',
                            style: const pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            'Certificate ID: $certId',
                            style: const pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static String filenameFor({
    required String kingdomName,
    required String titleName,
    DateTime? issuedAt,
  }) {
    final at = issuedAt ?? DateTime.now();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(at.toUtc());
    final k = kingdomName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final t = titleName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final safeK = k.isEmpty ? 'kingdom' : k;
    final safeT = t.isEmpty ? 'title' : t;
    return 'TenOfAKind_Title_${safeK}_${safeT}_$stamp.pdf';
  }

  static Future<void> downloadTitleCertificate({
    required String playerName,
    required String playerId,
    required String kingdomName,
    required String titleName,
    DateTime? issuedAt,
  }) async {
    final at = issuedAt ?? DateTime.now();
    final pdfBytes = await buildTitleCertificatePdf(
      playerName: playerName,
      playerId: playerId,
      kingdomName: kingdomName,
      titleName: titleName,
      issuedAt: at,
    );
    final filename = filenameFor(
      kingdomName: kingdomName,
      titleName: titleName,
      issuedAt: at,
    );

    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (_) {
      if (kIsWeb) {
        // No-op: web share may be blocked by pop-up settings.
      }
      rethrow;
    }
  }

  static int _fnv1a32(String s) {
    var hash = 0x811c9dc5;
    for (final cu in s.codeUnits) {
      hash ^= cu;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
