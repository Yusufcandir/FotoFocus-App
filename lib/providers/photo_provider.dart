import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/photo.dart';
import '../data/models/comment.dart';
import '../data/services/photo_service.dart';

class PhotoProvider extends ChangeNotifier {
  PhotoProvider({PhotoService? service}) : _service = service ?? PhotoService();

  final PhotoService _service;

  // -------------------------------
  // STATE
  // -------------------------------
  List<Photo> _photos = [];
  Photo? _photo;
  List<CommentModel> _comments = [];
  bool _loading = false;
  String? _error;
  bool _uploading = false;

  int? _myRating;

  int? _replyToCommentId;
  String? _replyToLabel;

  // -------------------------------
  // GETTERS
  // -------------------------------
  List<Photo> get photos => _photos;
  Photo? get photo => _photo;
  List<CommentModel> get comments => _comments;
  bool get loading => _loading;
  String? get error => _error;
  int? get myRating => _myRating;
  bool get uploading => _uploading;
  int? get replyToCommentId => _replyToCommentId;
  String? get replyToLabel => _replyToLabel;

  // -------------------------------
  // INTERNAL HELPERS
  // -------------------------------
  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setUploading(bool v) {
    _uploading = v;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void clearError() => _setError(null);

  // -------------------------------
  // REPLY CONTROLS
  // -------------------------------
  void startReply({required int commentId, required String label}) {
    _replyToCommentId = commentId;
    _replyToLabel = label;
    notifyListeners();
  }

  void cancelReply() {
    _replyToCommentId = null;
    _replyToLabel = null;
    notifyListeners();
  }

  /// Replace a photo in the list by id
  void _replaceInList(Photo updated) {
    final idx = _photos.indexWhere((p) => p.id == updated.id);
    if (idx != -1) _photos[idx] = updated;
  }

  /// Build a new Photo instance with updated rating fields
  Photo _withRating(Photo base, double avgRating, int ratingCount) {
    return Photo(
      id: base.id,
      challengeId: base.challengeId,
      imageUrl: base.imageUrl,
      caption: base.caption,
      userEmail: base.userEmail,
      createdAt: base.createdAt,
      avgRating: avgRating,
      ratingCount: ratingCount,
      userId: base.userId,
    );
  }

  // -------------------------------
  // FETCH PHOTOS FOR CHALLENGE
  // -------------------------------
  Future<void> loadChallengePhotos(int challengeId) async {
    _setLoading(true);
    _setError(null);

    try {
      _photos = await _service.fetchChallengePhotos(challengeId);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchChallengePhotos(int challengeId) async {
    try {
      _setLoading(true);
      _setError(null);

      _photos = await _service.fetchChallengePhotos(challengeId);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------
  // FETCH SINGLE PHOTO + COMMENTS + MY RATING
  // -------------------------------
  Future<void> fetchPhotoDetail(int photoId) async {
    try {
      _setLoading(true);
      _setError(null);

      _photo = await _service.fetchPhotoDetail(photoId);
      _comments = await _service.fetchComments(photoId);

      _myRating = await _service.fetchMyRating(photoId);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> pickAndUploadPhoto(int challengeId) async {
    final picker = ImagePicker();
    final x =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x == null) return;

    await uploadPhoto(challengeId: challengeId, photoFile: File(x.path));
  }

  Future<void> reloadComments(int photoId) async {
    try {
      _setError(null);
      _comments = await _service.fetchComments(photoId);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> deleteComment({
    required int photoId,
    required int commentId,
  }) async {
    try {
      await _service.deleteComment(commentId);

      // reload to keep tree correct
      await reloadComments(photoId);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> refreshMyRating(int photoId) async {
    try {
      _myRating = await _service.fetchMyRating(photoId);
      notifyListeners();
    } catch (_) {}
  }

  // -------------------------------
  // UPLOAD PHOTO
  // -------------------------------
  Future<void> uploadPhoto({
    required int challengeId,
    required File photoFile,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final newPhoto = await _service.uploadPhoto(
        challengeId: challengeId,
        photoFile: photoFile,
      );

      // add to top
      _photos.insert(0, newPhoto);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------
  // DELETE PHOTO (OWNER)
  // -------------------------------
  Future<void> deletePhoto(int photoId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _service.deletePhoto(photoId);

      _photos.removeWhere((p) => p.id == photoId);
      if (_photo?.id == photoId) {
        _photo = null;
        _comments = [];
        _myRating = null;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------
  // COMMENTS
  // -------------------------------
  Future<void> postComment(int photoId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    try {
      _setError(null);

      //  include parentId if in reply mode
      await _service.postComment(
        photoId,
        t,
        parentId: _replyToCommentId,
      );

      //  reload to ensure correct nesting in UI
      cancelReply();
      await reloadComments(photoId);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // -------------------------------
  // RATINGS
  // -------------------------------
  Future<void> ratePhoto(int photoId, int rating) async {
    try {
      _setError(null);

      final updated = await _service.ratePhoto(photoId, rating);

      final avg = (updated['avgRating'] is num)
          ? (updated['avgRating'] as num).toDouble()
          : 0.0;
      final cnt = (updated['ratingCount'] is num)
          ? (updated['ratingCount'] as num).toInt()
          : 0;

      if (_photo != null && _photo!.id == photoId) {
        _photo = _withRating(_photo!, avg, cnt);
      }

      final idx = _photos.indexWhere((p) => p.id == photoId);
      if (idx != -1) {
        _photos[idx] = _withRating(_photos[idx], avg, cnt);
      }

      _myRating = rating;

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> reportPhoto(int photoId, String reason) async {
    try {
      _setError(null);

      await _service.reportPhoto(photoId, reason);
    } catch (e) {
      _setError(e.toString());
    }
  }
}
