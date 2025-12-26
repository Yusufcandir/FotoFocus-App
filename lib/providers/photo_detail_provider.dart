import 'package:flutter/foundation.dart';
import '../data/models/photo.dart';
import '../data/models/comment.dart';
import '../data/services/photo_service.dart';

class PhotoDetailProvider extends ChangeNotifier {
  PhotoDetailProvider({PhotoService? service})
      : _service = service ?? PhotoService();

  final PhotoService _service;

  bool _loading = false;
  String? _error;

  Photo? _photo;
  List<CommentModel> _comments = [];

  bool get loading => _loading;
  String? get error => _error;

  Photo? get photo => _photo;
  List<CommentModel> get comments => _comments;
  int? _myRating;
  int? get myRating => _myRating;

  Future<void> load(int photoId) async {
    _setLoading(true);
    try {
      _photo = await _service.fetchPhotoDetail(photoId);
      _comments = await _service.fetchComments(photoId);
      _myRating = await _service.fetchMyRating(photoId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deletePhoto(int photoId) async {
    await _service.deletePhoto(photoId);
  }

  Future<void> addComment(int photoId, String text) async {
    if (text.trim().isEmpty) return;
    try {
      final created = await _service.postComment(photoId, text.trim());
      _comments = [created, ..._comments]; // newest first
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> ratePhoto(int photoId, int value) async {
    try {
      final updated = await _service.ratePhoto(photoId, value);

      if (_photo == null) return; // ✅ guard

      _photo = _photo!.copyWith(
        avgRating: (updated['avgRating'] as num).toDouble(),
        ratingCount: (updated['ratingCount'] as num).toInt(),
      );
      _myRating = value;

      notifyListeners();
    } catch (e) {
      debugPrint("Rating failed: $e");
    }
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void replacePhoto(Photo updated) {
    _photo = updated;
    notifyListeners();
  }
}
