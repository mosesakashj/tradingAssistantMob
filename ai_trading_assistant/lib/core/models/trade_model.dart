import 'package:cloud_firestore/cloud_firestore.dart';

class TradeModel {
  final String id;
  final String symbol;
  final String market; // 'forex'|'metals'|'crypto'|'indices'
  final String direction; // 'buy' | 'sell'
  final double lots;
  final double entryPrice;
  final double? exitPrice;
  final double? stopLoss;
  final double? takeProfit;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status; // 'open' | 'closed' | 'cancelled'
  final double? pnl;
  final double? pips;
  final double? riskPercent;
  final double? riskRewardPlanned;
  final String session; // 'asian'|'london'|'newyork'|'overlap'|'none'
  final String setup; // 'breakout'|'pullback'|'reversal'|'trend_continuation'|'sr_bounce'|custom|'none'
  final List<String> mistakeTags;
  final int? emotionConfidence; // 1–5
  final int? emotionFear; // 1–5
  final String? emotionState; // 'calm'|'anxious'|'confident'|'frustrated'|'excited'
  final int? satisfactionScore; // 1–5
  final String? lessonsLearned;
  final String? entryScreenshotUrl;
  final String? exitScreenshotUrl;
  final Map<String, dynamic>? aiReview; // {strengths, weaknesses, suggestions, score}
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TradeModel({
    required this.id,
    required this.symbol,
    this.market = 'metals',
    required this.direction,
    required this.lots,
    required this.entryPrice,
    this.exitPrice,
    this.stopLoss,
    this.takeProfit,
    required this.openedAt,
    this.closedAt,
    required this.status,
    this.pnl,
    this.pips,
    this.riskPercent,
    this.riskRewardPlanned,
    this.session = 'none',
    this.setup = 'none',
    this.mistakeTags = const [],
    this.emotionConfidence,
    this.emotionFear,
    this.emotionState,
    this.satisfactionScore,
    this.lessonsLearned,
    this.entryScreenshotUrl,
    this.exitScreenshotUrl,
    this.aiReview,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TradeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();
    return TradeModel(
      id: doc.id,
      symbol: data['symbol'] as String? ?? '',
      market: data['market'] as String? ?? 'metals',
      direction: data['direction'] as String? ?? 'buy',
      lots: (data['lots'] as num?)?.toDouble() ?? 0.0,
      entryPrice: (data['entryPrice'] as num?)?.toDouble() ?? 0.0,
      exitPrice: (data['exitPrice'] as num?)?.toDouble(),
      stopLoss: (data['stopLoss'] as num?)?.toDouble(),
      takeProfit: (data['takeProfit'] as num?)?.toDouble(),
      openedAt: (data['openedAt'] as Timestamp?)?.toDate() ?? now,
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'open',
      pnl: (data['pnl'] as num?)?.toDouble(),
      pips: (data['pips'] as num?)?.toDouble(),
      riskPercent: (data['riskPercent'] as num?)?.toDouble(),
      riskRewardPlanned: (data['riskRewardPlanned'] as num?)?.toDouble(),
      session: data['session'] as String? ?? 'none',
      setup: data['setup'] as String? ?? 'none',
      mistakeTags: List<String>.from(data['mistakeTags'] as List? ?? []),
      emotionConfidence: (data['emotionConfidence'] as num?)?.toInt(),
      emotionFear: (data['emotionFear'] as num?)?.toInt(),
      emotionState: data['emotionState'] as String?,
      satisfactionScore: (data['satisfactionScore'] as num?)?.toInt(),
      lessonsLearned: data['lessonsLearned'] as String?,
      entryScreenshotUrl: data['entryScreenshotUrl'] as String?,
      exitScreenshotUrl: data['exitScreenshotUrl'] as String?,
      aiReview: data['aiReview'] as Map<String, dynamic>?,
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? now,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'symbol': symbol,
        'market': market,
        'direction': direction,
        'lots': lots,
        'entryPrice': entryPrice,
        'exitPrice': exitPrice,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'openedAt': Timestamp.fromDate(openedAt),
        'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
        'status': status,
        'pnl': pnl,
        'pips': pips,
        'riskPercent': riskPercent,
        'riskRewardPlanned': riskRewardPlanned,
        'session': session,
        'setup': setup,
        'mistakeTags': mistakeTags,
        'emotionConfidence': emotionConfidence,
        'emotionFear': emotionFear,
        'emotionState': emotionState,
        'satisfactionScore': satisfactionScore,
        'lessonsLearned': lessonsLearned,
        'entryScreenshotUrl': entryScreenshotUrl,
        'exitScreenshotUrl': exitScreenshotUrl,
        'aiReview': aiReview,
        'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  TradeModel copyWith({
    String? id,
    String? symbol,
    String? market,
    String? direction,
    double? lots,
    double? entryPrice,
    double? exitPrice,
    double? stopLoss,
    double? takeProfit,
    DateTime? openedAt,
    DateTime? closedAt,
    String? status,
    double? pnl,
    double? pips,
    double? riskPercent,
    double? riskRewardPlanned,
    String? session,
    String? setup,
    List<String>? mistakeTags,
    int? emotionConfidence,
    int? emotionFear,
    String? emotionState,
    int? satisfactionScore,
    String? lessonsLearned,
    String? entryScreenshotUrl,
    String? exitScreenshotUrl,
    Map<String, dynamic>? aiReview,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TradeModel(
        id: id ?? this.id,
        symbol: symbol ?? this.symbol,
        market: market ?? this.market,
        direction: direction ?? this.direction,
        lots: lots ?? this.lots,
        entryPrice: entryPrice ?? this.entryPrice,
        exitPrice: exitPrice ?? this.exitPrice,
        stopLoss: stopLoss ?? this.stopLoss,
        takeProfit: takeProfit ?? this.takeProfit,
        openedAt: openedAt ?? this.openedAt,
        closedAt: closedAt ?? this.closedAt,
        status: status ?? this.status,
        pnl: pnl ?? this.pnl,
        pips: pips ?? this.pips,
        riskPercent: riskPercent ?? this.riskPercent,
        riskRewardPlanned: riskRewardPlanned ?? this.riskRewardPlanned,
        session: session ?? this.session,
        setup: setup ?? this.setup,
        mistakeTags: mistakeTags ?? this.mistakeTags,
        emotionConfidence: emotionConfidence ?? this.emotionConfidence,
        emotionFear: emotionFear ?? this.emotionFear,
        emotionState: emotionState ?? this.emotionState,
        satisfactionScore: satisfactionScore ?? this.satisfactionScore,
        lessonsLearned: lessonsLearned ?? this.lessonsLearned,
        entryScreenshotUrl: entryScreenshotUrl ?? this.entryScreenshotUrl,
        exitScreenshotUrl: exitScreenshotUrl ?? this.exitScreenshotUrl,
        aiReview: aiReview ?? this.aiReview,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
