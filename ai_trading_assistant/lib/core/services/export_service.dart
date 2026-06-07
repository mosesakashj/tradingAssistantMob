import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trade_model.dart';

class ExportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final _numFormat = NumberFormat('#,##0.00');

  // ── CSV ──────────────────────────────────────────────────────────────────

  static Future<void> exportTradesToCsv(List<TradeModel> trades) async {
    final rows = <List<dynamic>>[
      [
        'ID', 'Pair', 'Direction', 'Lots', 'Entry Price',
        'Exit Price', 'Stop Loss', 'Take Profit', 'P&L',
        'Pips', 'Opened At', 'Closed At', 'Status', 'Note',
      ]
    ];

    for (final t in trades) {
      rows.add([
        t.id,
        t.symbol,
        t.direction,
        t.lots,
        t.entryPrice,
        t.exitPrice ?? '',
        t.stopLoss ?? '',
        t.takeProfit ?? '',
        t.pnl != null ? _numFormat.format(t.pnl) : '',
        t.pips != null ? _numFormat.format(t.pips) : '',
        _dateFormat.format(t.openedAt),
        t.closedAt != null ? _dateFormat.format(t.closedAt!) : '',
        t.status,
        t.note ?? '',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final file = await _writeTempFile('trades_export.csv', csvString);
    await Share.shareXFiles([XFile(file.path)], text: 'AI Trading Assistant — Trade Export');
  }

  // ── PDF ──────────────────────────────────────────────────────────────────

  static Future<void> exportTradesToPdf(
    List<TradeModel> trades, {
    required double winRate,
    required double totalPnl,
    required double totalPips,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (_) => pw.Text(
          'AI Trading Assistant — Trade Report',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        footer: (ctx) => pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Row(children: [
            _pdfStat('Win Rate', '${winRate.toStringAsFixed(1)}%'),
            _pdfStat('Net P&L', '\$${_numFormat.format(totalPnl)}'),
            _pdfStat('Total Pips', _numFormat.format(totalPips)),
          ]),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'Pair', 'Dir', 'Lots', 'Entry', 'Exit', 'P&L', 'Pips', 'Closed'
            ],
            data: trades
                .where((t) => t.status == 'closed')
                .map((t) => [
                      t.symbol,
                      t.direction.toUpperCase(),
                      t.lots.toString(),
                      t.entryPrice.toString(),
                      t.exitPrice?.toString() ?? '-',
                      t.pnl != null ? '\$${_numFormat.format(t.pnl)}' : '-',
                      t.pips != null ? _numFormat.format(t.pips) : '-',
                      t.closedAt != null
                          ? DateFormat('MM/dd HH:mm').format(t.closedAt!)
                          : '-',
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle:
                pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final file = await _writeTempFileBytes('trade_report.pdf', bytes);
    await Printing.sharePdf(bytes: bytes, filename: file.path.split('/').last);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static pw.Widget _pdfStat(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static Future<File> _writeTempFile(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    return file;
  }

  static Future<File> _writeTempFileBytes(
      String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }
}
