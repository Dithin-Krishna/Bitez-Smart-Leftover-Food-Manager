import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Model representing a user suggestion or feedback item.
class AppSuggestion {
  final String id;
  final String title;
  final String description;
  final String category; // 'feature', 'ui_ux', 'recipe_idea', 'bug_report', 'general'
  final int rating;
  final String status; // 'under_review', 'planned', 'implemented', 'closed'
  final String? userName;
  final DateTime createdAt;

  const AppSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.rating,
    required this.status,
    this.userName,
    required this.createdAt,
  });

  factory AppSuggestion.fromJson(Map<String, dynamic> json) {
    return AppSuggestion(
      id: (json['_id'] ?? json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'feature',
      rating: (json['rating'] is num) ? (json['rating'] as num).toInt() : 5,
      status: json['status']?.toString() ?? 'under_review',
      userName: json['userName']?.toString(),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'rating': rating,
    'status': status,
    'userName': userName,
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

  static const String _localSuggestionsKey = 'bitez_user_suggestions_cache';

  /// Submits an app suggestion to the backend with automatic offline caching.
  Future<AppSuggestion> submitSuggestion({
    String? token,
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
      title: title.trim(),
      description: description.trim(),
      category: category,
      rating: rating,
      status: 'under_review',
      userName: isAnonymous ? 'Anonymous' : (userName ?? 'You'),
      createdAt: DateTime.now(),
    );

    // 3. Save to local storage cache so user can review their past suggestions
    await _saveToLocalCache(created);

    return created;
  }

  /// Fetches suggestions submitted by current user (with local cache fallback)
  Future<List<AppSuggestion>> getMySuggestions({String? token}) async {
    // Attempt online fetch if authenticated
    if (token != null && token.isNotEmpty) {
      try {
        final res = await ApiService.instance.get('/api/suggestions/my', token: token);
        if (res['success'] == true && res['data'] is List) {
          final list = (res['data'] as List)
              .map((item) => AppSuggestion.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();

          // Merge with any offline local-only items
          final localItems = await getLocalSuggestions();
          final serverIds = list.map((e) => e.id).toSet();
          final missingLocals = localItems.where((loc) => !serverIds.contains(loc.id));
          return [...missingLocals, ...list];
        }
      } catch (e) {
        debugPrint('SuggestionService.getMySuggestions remote failed: $e');
      }
    }

    return getLocalSuggestions();
  }

  /// Reads locally cached suggestions
  Future<List<AppSuggestion>> getLocalSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localSuggestionsKey);
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

  Future<void> _saveToLocalCache(AppSuggestion item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_localSuggestionsKey) ?? [];
      existing.insert(0, jsonEncode(item.toJson()));
      // Cap at most recent 50
      if (existing.length > 50) {
        existing.removeRange(50, existing.length);
      }
      await prefs.setStringList(_localSuggestionsKey, existing);
    } catch (e) {
      debugPrint('Error saving suggestion to cache: $e');
    }
  }
}
