import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../repo/like_repo.dart';

final likeRepoProvider = Provider((ref) => LikeRepository());

final likeProvider =
    StateNotifierProvider<LikeNotifier, AsyncValue<List<dynamic>>>(
  (ref) => LikeNotifier(ref.read(likeRepoProvider)),
);

int _safeId(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is Map) return _safeId(v['id']);
  return int.tryParse(v.toString()) ?? 0;
}

bool _matchesLikeItem(dynamic raw, int targetId, [String? targetType]) {
  if (raw is! Map || targetId <= 0) return false;
  final item = Map<String, dynamic>.from(raw);
  final normType = targetType?.toLowerCase().trim();

  final aptId = _safeId(item['apartmentId']) > 0
      ? _safeId(item['apartmentId'])
      : _safeId(item['apartment'] ?? item['Apartment']);

  final commId = _safeId(item['commercialId']) > 0
      ? _safeId(item['commercialId'])
      : _safeId(item['commercial'] ?? item['Commercial']);

  final flatId = _safeId(item['flatmateId']) > 0
      ? _safeId(item['flatmateId'])
      : _safeId(item['flatmate'] ?? item['Flatmate'] ?? item['flatmates']);

  final pgId = _safeId(item['propertyId']) > 0
      ? _safeId(item['propertyId'])
      : (_safeId(item['pgId']) > 0
          ? _safeId(item['pgId'])
          : _safeId(item['property'] ?? item['pg'] ?? item['home']));

  if (normType == 'apartment') {
    if (aptId > 0 && aptId == targetId) return true;
    if (aptId == 0 && commId == 0 && flatId == 0 && pgId == targetId) return true;
    return false;
  }

  if (normType == 'commercial') {
    if (commId > 0 && commId == targetId) return true;
    if (commId == 0 && aptId == 0 && flatId == 0 && pgId == targetId) return true;
    return false;
  }

  if (normType == 'flatmate') {
    if (flatId > 0 && flatId == targetId) return true;
    if (flatId == 0 && aptId == 0 && commId == 0 && pgId == targetId) return true;
    return false;
  }

  if (normType == 'pg' || normType == 'property') {
    if (pgId > 0 && pgId == targetId) return true;
    return false;
  }

  // If no type specified: matches ANY of the IDs
  return (aptId == targetId || commId == targetId || flatId == targetId || pgId == targetId);
}

class LikeNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final LikeRepository repo;

  LikeNotifier(this.repo) : super(const AsyncValue.loading()) {
    loadLikes();
  }

  Future<void> loadLikes() async {
    try {
      final data = await repo.fetchLikes();

      final validData = data.where((item) {
        if (item is! Map) return false;
        return true;
      }).toList();

      state = AsyncValue.data(validData);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> toggle(int id, [String? type]) async {
    if (id <= 0) return false;

    final current = List<dynamic>.from(state.value ?? []);
    final wasLiked = isLiked(id, type);

    // Optimistic update
    if (wasLiked) {
      final updated = current.where((item) => !_matchesLikeItem(item, id, type)).toList();
      state = AsyncValue.data(updated);
    } else {
      final synthetic = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'propertyId': (type == 'pg' || type == 'property') ? id : null,
        'apartmentId': type == 'apartment' ? id : null,
        'commercialId': type == 'commercial' ? id : null,
        'flatmateId': type == 'flatmate' ? id : null,
        'createdAt': DateTime.now().toIso8601String(),
      };
      state = AsyncValue.data([synthetic, ...current]);
    }

    try {
      final isNowLiked = await repo.toggleLike(id, type);

      if (isNowLiked) {
        await loadLikes();
      } else {
        final updated = (state.value ?? []).where((item) => !_matchesLikeItem(item, id, type)).toList();
        state = AsyncValue.data(updated);
      }
      return isNowLiked;
    } catch (e) {
      // Re-sync with backend data
      await loadLikes();
      return isLiked(id, type);
    }
  }

  bool isLiked(int id, [String? type]) {
    if (id <= 0) return false;
    return state.maybeWhen(
      data: (likes) {
        for (final item in likes) {
          if (_matchesLikeItem(item, id, type)) return true;
        }
        return false;
      },
      orElse: () => false,
    );
  }
}
