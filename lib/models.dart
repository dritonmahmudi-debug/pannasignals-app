// Minimal models and enums for signals_app

enum AnalysisType { scalp, swing, unknown }

enum StatsPeriod { day, week, month, all }

class Signal {
  final String id;
  final String symbol;
  final String timeframe;
  final double? entry;
  final double? sl;
  final double? tp;
  final bool? isClosed;
  final bool? isFavorite;
  final bool? isPremium;
  final AnalysisType analysisType;

  Signal({
    required this.id,
    required this.symbol,
    required this.timeframe,
    this.entry,
    this.sl,
    this.tp,
    this.isClosed,
    this.isFavorite,
    this.isPremium,
    this.analysisType = AnalysisType.unknown,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      timeframe: json['timeframe'] ?? '',
      entry: (json['entry'] as num?)?.toDouble(),
      sl: (json['sl'] as num?)?.toDouble(),
      tp: (json['tp'] as num?)?.toDouble(),
      isClosed: json['isClosed'] as bool?,
      isFavorite: json['isFavorite'] as bool?,
      isPremium: json['isPremium'] as bool?,
      analysisType: AnalysisType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['analysisType'] ?? 'unknown'),
        orElse: () => AnalysisType.unknown,
      ),
    );
  }
}

class StatsResponse {
  final int totalSignals;
  final int winCount;
  final int lossCount;
  final double? winRate;

  StatsResponse({
    required this.totalSignals,
    required this.winCount,
    required this.lossCount,
    this.winRate,
  });

  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    return StatsResponse(
      totalSignals: json['totalSignals'] ?? 0,
      winCount: json['winCount'] ?? 0,
      lossCount: json['lossCount'] ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble(),
    );
  }
}
