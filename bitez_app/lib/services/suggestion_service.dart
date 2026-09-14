import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Model representing a user suggestion or feedback item.
class AppSuggestion {
  final String id;
  final String? userId;
  final String title;
  final String description;
  final String category; // 'feature', 'ui_ux', 'recipe_idea', 'bug_report', 'general'
  final int rating;
  final String status; // 'under_review', 'planned', 'implemented', 'closed'
  final String? userName;
  final String? userEmail;
  final DateTime createdAt;

  const AppSuggestion({
    required this.id,
    this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.rating,
    required this.status,
    this.userName,
    this.userEmail,
    required this.createdAt,
  });

  factory AppSuggestion.fromJson(Map<String, dynamic> json) {
    return AppSuggestion(
      id: (json['_id'] ?? json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      userId: json['userId']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'feature',
      rating: (json['rating'] is num) ? (json['rating'] as num).toInt() : 5,
      status: json['status']?.toString() ?? 'under_review',
      userName: json['userName']?.toString(),
      userEmail: json['userEmail']?.toString(),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'category': category,
    'rating': rating,
    'status': status,
    'userName': userName,
    'userEmail': userEmail,
    'createdAt': createdAt.toIso8601String(),
  };

  String get categoryDisplayName {
    switch (category) {
      case 'feature':
        return 'Feature Request';
      case 'ui_ux':
        return 'UI & Design';
      case 'recipe_idea':
        return 'Recipe & Ingredients';
      case 'bug_report':
        return 'Bug Report';
      case 'general':
      default:
        return 'General Idea';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'planned':
        return 'Planned 💡';
      case 'implemented':
        return 'Implemented ✨';
      case 'closed':
        return 'Resolved ✅';
      case 'under_review':
      default:
        return 'Under Review ⏳';
    }
  }
}

/// Service managing app suggestions, feedback submissions, and local offline history.
class SuggestionService {
  SuggestionService._();
  static final SuggestionService instance = SuggestionService._();

  static String _cacheKey(String? userId) =>
      userId != null && userId.isNotEmpty
          ? 'bitez_suggestions_user_$userId'
          : 'bitez_suggestions_user_anon';

  /// Submits an app suggestion to the backend with automatic per-user offline caching.
  Future<AppSuggestion> submitSuggestion({
    String? token,
    String? userId,
    required String title,
    required String description,
    required String category,
    required int rating,
    bool isAnonymous = false,
    String? userName,
    String? userEmail,
  }) async {
    final payload = {
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'rating': rating,
      'isAnonymous': isAnonymous,
      'userName': ?userName,
      'userEmail': ?userEmail,
    };

    AppSuggestion? created;

    // 1. Attempt online submission to backend API
    try {
      final res = await ApiService.instance.post(
        '/api/suggestions',
        payload,
        token: token,
      );

      if (res['success'] == true && res['data'] != null) {
        created = AppSuggestion.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('SuggestionService.submitSuggestion online call failed: $e. Falling back to local queue.');
    }

    // 2. If offline or call failed, create local fallback item
    created ??= AppSuggestion(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: title.trim(),
      description: description.trim(),
      category: category,
      rating: rating,
      status: 'under_review',
      userName: isAnonymous ? 'Anonymous' : (userName ?? 'You'),
      userEmail: isAnonymous ? null : userEmail,
      createdAt: DateTime.now(),
    );

    // 3. Save to user-scoped local storage cache
    await _saveToLocalCache(created, userId: userId);

    return created;
  }

  /// Fetches suggestions submitted by current user (strictly scoped to current user/admin)
  Future<List<AppSuggestion>> getMySuggestions({String? token, String? userId}) async {
    // Purge any legacy shared cache to prevent cross-user contamination
    await _purgeLegacyCache();

    // 1. Attempt online fetch if authenticated
    if (token != null && token.isNotEmpty) {
      try {
        final res = await ApiService.instance.get('/api/suggestions/my', token: token);
        if (res['success'] == true && res['data'] is List) {
          final list = (res['data'] as List)
              .map((item) => AppSuggestion.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();

          // Sync verified server list to current user's local cache
          await _setLocalSuggestions(list, userId: userId);
          return list;
        }
      } catch (e) {
        debugPrint('SuggestionService.getMySuggestions remote failed: $e');
      }
    }

    // 2. Fallback to current user's private local cache when offline
    return getLocalSuggestions(userId: userId);
  }

  /// Reads user-scoped cached suggestions (strictly for the logged-in user)
  Future<List<AppSuggestion>> getLocalSuggestions({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(userId);
      final raw = prefs.getStringList(key);
      if (raw == null || raw.isEmpty) return [];

      return raw
          .map((str) {
            try {
              final map = jsonDecode(str) as Map<String, dynamic>;
              return AppSuggestion.fromJson(map);
            } catch (_) {
              return null;
            }
          })
          .whereType<AppSuggestion>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error reading local suggestions: $e');
      return [];
    }
  }

  Future<void> _setLocalSuggestions(List<AppSuggestion> items, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(userId);
      final list = items.take(50).map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(key, list);
    } catch (e) {
      debugPrint('Error writing suggestions cache: $e');
    }
  }

  Future<void> _saveToLocalCache(AppSuggestion item, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(userId);
      final existing = prefs.getStringList(key) ?? [];
      existing.insert(0, jsonEncode(item.toJson()));
      if (existing.length > 50) {
        existing.removeRange(50, existing.length);
      }
      await prefs.setStringList(key, existing);
    } catch (e) {
      debugPrint('Error saving suggestion to cache: $e');
    }
  }

  Future<void> _removeFromLocalCache(String id, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(userId);
      final existing = prefs.getStringList(key);
      if (existing == null) return;
      existing.removeWhere((str) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return map['id'] == id || map['_id'] == id;
        } catch (_) {
          return false;
        }
      });
      await prefs.setStringList(key, existing);
    } catch (e) {
      debugPrint('Error removing suggestion from cache: $e');
    }
  }

  /// Removes old un-scoped shared cache if present on the device
  Future<void> _purgeLegacyCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('bitez_user_suggestions_cache')) {
        await prefs.remove('bitez_user_suggestions_cache');
      }
    } catch (_) {}
  }

  /// Admin only: updates status of a user's suggestion
  Future<bool> updateSuggestionStatus({
    required String id,
    required String status,
    required String token,
  }) async {
    try {
      final res = await ApiService.instance.patch(
        '/api/suggestions/$id/status',
        {'status': status},
        token: token,
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('SuggestionService.updateSuggestionStatus failed: $e');
      return false;
    }
  }

  /// Deletes a suggestion (author or admin)
  Future<bool> deleteSuggestion({
    required String id,
    required String token,
    String? userId,
  }) async {
    try {
      final res = await ApiService.instance.delete(
        '/api/suggestions/$id',
        token: token,
      );
      if (res['success'] == true) {
        await _removeFromLocalCache(id, userId: userId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SuggestionService.deleteSuggestion failed: $e');
      // If offline and it is a local-only item, remove it locally
      if (id.startsWith('local_')) {
        await _removeFromLocalCache(id, userId: userId);
        return true;
      }
      return false;
    }
  }
}
