enum StatsPeriod {
  daily,
  weekly,
  monthly,
  all,
}

extension StatsPeriodExt on StatsPeriod {
  String get label {
    switch (this) {
      case StatsPeriod.daily:
        return 'Daily';
      case StatsPeriod.weekly:
        return 'Weekly';
      case StatsPeriod.monthly:
        return 'Monthly';
      case StatsPeriod.all:
        return 'All Time';
    }
  }
  String get apiValue {
    switch (this) {
      case StatsPeriod.daily:
        return 'daily';
      case StatsPeriod.weekly:
        return 'weekly';
      case StatsPeriod.monthly:
        return 'monthly';
      case StatsPeriod.all:
        return 'all';
    }
  }
}
