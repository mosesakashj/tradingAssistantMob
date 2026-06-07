import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsModel {
  final int leverage;
  final int contractSizeXauusd;
  final int contractSizeXagusd;
  final int contractSizeForex;   // standard lot = 100,000 units
  final int contractSizeIndices; // e.g. US30 = 1
  final int contractSizeCrypto;  // BTC/ETH typically 1
  final String accountType; // 'usd' | 'cent'
  final double marginCallPct;
  final double stopoutPct;
  final double startingCapital;
  final String nimModel;
  final double nimTemperature;
  final String nimBaseUrl;
  final String aiLanguage;

  const SettingsModel({
    required this.leverage,
    required this.contractSizeXauusd,
    required this.contractSizeXagusd,
    this.contractSizeForex = 100000,
    this.contractSizeIndices = 1,
    this.contractSizeCrypto = 1,
    required this.accountType,
    required this.marginCallPct,
    required this.stopoutPct,
    required this.startingCapital,
    required this.nimModel,
    required this.nimTemperature,
    required this.nimBaseUrl,
    required this.aiLanguage,
  });

  static SettingsModel defaults() => const SettingsModel(
        leverage: 100,
        contractSizeXauusd: 100,
        contractSizeXagusd: 5000,
        contractSizeForex: 100000,
        contractSizeIndices: 1,
        contractSizeCrypto: 1,
        accountType: 'usd',
        marginCallPct: 100.0,
        stopoutPct: 20.0,
        startingCapital: 10000.0,
        nimModel: 'meta/llama-3.1-nemotron-70b-instruct',
        nimTemperature: 0.7,
        nimBaseUrl: 'https://integrate.api.nvidia.com/v1',
        aiLanguage: 'en',
      );

  factory SettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SettingsModel(
      leverage: (data['leverage'] as num?)?.toInt() ?? 100,
      contractSizeXauusd:
          (data['contractSizeXauusd'] as num?)?.toInt() ?? 100,
      contractSizeXagusd:
          (data['contractSizeXagusd'] as num?)?.toInt() ?? 5000,
      contractSizeForex:
          (data['contractSizeForex'] as num?)?.toInt() ?? 100000,
      contractSizeIndices:
          (data['contractSizeIndices'] as num?)?.toInt() ?? 1,
      contractSizeCrypto:
          (data['contractSizeCrypto'] as num?)?.toInt() ?? 1,
      accountType: data['accountType'] as String? ?? 'usd',
      marginCallPct: (data['marginCallPct'] as num?)?.toDouble() ?? 100.0,
      stopoutPct: (data['stopoutPct'] as num?)?.toDouble() ?? 20.0,
      startingCapital:
          (data['startingCapital'] as num?)?.toDouble() ?? 10000.0,
      nimModel: data['nimModel'] as String? ??
          'meta/llama-3.1-nemotron-70b-instruct',
      nimTemperature: (data['nimTemperature'] as num?)?.toDouble() ?? 0.7,
      nimBaseUrl: data['nimBaseUrl'] as String? ??
          'https://integrate.api.nvidia.com/v1',
      aiLanguage: data['aiLanguage'] as String? ?? 'en',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'leverage': leverage,
        'contractSizeXauusd': contractSizeXauusd,
        'contractSizeXagusd': contractSizeXagusd,
        'contractSizeForex': contractSizeForex,
        'contractSizeIndices': contractSizeIndices,
        'contractSizeCrypto': contractSizeCrypto,
        'accountType': accountType,
        'marginCallPct': marginCallPct,
        'stopoutPct': stopoutPct,
        'startingCapital': startingCapital,
        'nimModel': nimModel,
        'nimTemperature': nimTemperature,
        'nimBaseUrl': nimBaseUrl,
        'aiLanguage': aiLanguage,
      };

  SettingsModel copyWith({
    int? leverage,
    int? contractSizeXauusd,
    int? contractSizeXagusd,
    int? contractSizeForex,
    int? contractSizeIndices,
    int? contractSizeCrypto,
    String? accountType,
    double? marginCallPct,
    double? stopoutPct,
    double? startingCapital,
    String? nimModel,
    double? nimTemperature,
    String? nimBaseUrl,
    String? aiLanguage,
  }) =>
      SettingsModel(
        leverage: leverage ?? this.leverage,
        contractSizeXauusd: contractSizeXauusd ?? this.contractSizeXauusd,
        contractSizeXagusd: contractSizeXagusd ?? this.contractSizeXagusd,
        contractSizeForex: contractSizeForex ?? this.contractSizeForex,
        contractSizeIndices: contractSizeIndices ?? this.contractSizeIndices,
        contractSizeCrypto: contractSizeCrypto ?? this.contractSizeCrypto,
        accountType: accountType ?? this.accountType,
        marginCallPct: marginCallPct ?? this.marginCallPct,
        stopoutPct: stopoutPct ?? this.stopoutPct,
        startingCapital: startingCapital ?? this.startingCapital,
        nimModel: nimModel ?? this.nimModel,
        nimTemperature: nimTemperature ?? this.nimTemperature,
        nimBaseUrl: nimBaseUrl ?? this.nimBaseUrl,
        aiLanguage: aiLanguage ?? this.aiLanguage,
      );
}
