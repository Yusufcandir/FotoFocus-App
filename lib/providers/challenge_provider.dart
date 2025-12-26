import 'dart:io';
import 'package:flutter/foundation.dart';

import '../data/models/challenge.dart';
import '../data/services/challenge_service.dart';

class ChallengeProvider extends ChangeNotifier {
  ChallengeProvider({ChallengeService? service})
      : _service = service ?? ChallengeService();

  final ChallengeService _service;

  bool _loading = false;
  String? _error;
  List<Challenge> _challenges = [];

  bool get loading => _loading;
  String? get error => _error;
  List<Challenge> get challenges => _challenges;

  /// Some older UIs rely on "featured" and "others".
  /// If your Challenge model has `featured`, keep using it.
  /// If not, it will safely behave like "not featured".
  bool _isFeatured(Challenge c) {
    try {
      // If your model has `featured`, this works.
      // If it doesn't, this will throw and return false.
      // ignore: unnecessary_cast
      return (c as dynamic).featured == true;
    } catch (_) {
      return false;
    }
  }

  List<Challenge> get featured => _challenges.where(_isFeatured).toList();
  List<Challenge> get others =>
      _challenges.where((c) => !_isFeatured(c)).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async => loadChallenges();

  Future<void> loadChallenges() async {
    _setLoading(true);
    _setError(null);

    try {
      final list = await _service.fetchChallenges();

      // ✅ Avoid duplicates (if you already inserted a newly created item)
      final seen = <int>{};
      _challenges = [];
      for (final c in list) {
        if (!seen.contains(c.id)) {
          seen.add(c.id);
          _challenges.add(c);
        }
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createChallenge({
    required String title,
    String? description,
    File? coverFile,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final challenge = await _service.createChallenge(
        title: title,
        description: description,
        coverFile: coverFile,
      );

      // ✅ Insert newest at top, but prevent duplicate id
      _challenges.removeWhere((c) => c.id == challenge.id);
      _challenges.insert(0, challenge);

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteChallenge(int challengeId) async {
    await _service.deleteChallenge(challengeId);
    _challenges.removeWhere((c) => c.id == challengeId);
    notifyListeners();
  }

  Future<void> updateChallenge({
    required int challengeId,
    required String title,
    required String description,
  }) async {
    final updated = await _service.updateChallenge(
      challengeId,
      title: title,
      description: description,
    );

    _challenges = _challenges.map((c) {
      if (c.id == challengeId) {
        return updated;
      }
      return c;
    }).toList();

    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }
}
