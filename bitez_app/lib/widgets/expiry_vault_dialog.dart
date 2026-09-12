import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/fridge_item_model.dart';
import '../screens/recipe_results_screen.dart';
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String val, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
