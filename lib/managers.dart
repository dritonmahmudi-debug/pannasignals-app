// Minimal managers for signals_app

import 'models.dart';

class FavoritesManager {
  final Set<String> _favoriteIds = {};

  bool isFavorite(Signal signal) => _favoriteIds.contains(signal.id);

  void toggleFavorite(Signal signal) {
    if (isFavorite(signal)) {
      _favoriteIds.remove(signal.id);
    } else {
      _favoriteIds.add(signal.id);
    }
  }
}

class PremiumManager {
  bool isPremium = false;
}
