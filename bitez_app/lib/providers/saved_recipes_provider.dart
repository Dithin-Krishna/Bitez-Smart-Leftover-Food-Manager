import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';

/// Manages bookmarked / saved recipes using SharedPreferences.
class SavedRecipesProvider extends ChangeNotifier {
  static const String _keySaved = 'saved_recipes_json_v1';

  final List<RecipeModel> _savedRecipes = [];

  List<RecipeModel> get savedRecipes => List.unmodifiable(_savedRecipes);

  bool isSaved(int recipeId) {
    return _savedRecipes.any((r) => r.id == recipeId);
  }

  Future<void> loadSavedRecipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? jsonList = prefs.getStringList(_keySaved);
      if (jsonList != null) {
        _savedRecipes.clear();
        for (final str in jsonList) {
          _savedRecipes.add(RecipeModel.fromJson(jsonDecode(str)));
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleSave(RecipeModel recipe) async {
    final index = _savedRecipes.indexWhere((r) => r.id == recipe.id);
    if (index >= 0) {
      _savedRecipes.removeAt(index);
    } else {
      _savedRecipes.add(recipe);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _savedRecipes.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_keySaved, jsonList);
    } catch (_) {}
  }
}
