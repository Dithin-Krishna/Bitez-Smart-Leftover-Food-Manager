import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/saved_recipes_provider.dart';
import 'recipe_detail_screen.dart';

class SavedRecipesScreen extends StatelessWidget {
  const SavedRecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final savedProvider = context.watch<SavedRecipesProvider>();
    final savedList = savedProvider.savedRecipes;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
        title: Text(
          'Saved Recipes',
          style: TextStyle(fontWeight: FontWeight.w700, color: theme.appBarTheme.foregroundColor),
        ),
      ),
      body: savedList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No saved recipes yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bookmark your favorite recipes to view them here.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: savedList.length,
              itemBuilder: (context, index) {
                final recipe = savedList[index];
                return Dismissible(
                  key: Key('saved_${recipe.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    savedProvider.toggleSave(recipe);
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    color: theme.cardColor,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: recipe.image.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                recipe.image,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.restaurant, color: primary),
                            ),
                      title: Text(
                        recipe.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: recipe.readyInMinutes != null
                          ? Text(
                              '${recipe.readyInMinutes} mins',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.bookmark, color: Colors.amber),
                        onPressed: () => savedProvider.toggleSave(recipe),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: recipe),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
