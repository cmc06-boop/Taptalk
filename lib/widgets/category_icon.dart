import 'package:flutter/material.dart';

import '../data/models/category_model.dart';

/// Renders the Material icon for a [CategoryModel].
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 24,
    this.color,
  });

  final CategoryModel category;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      category.icon,
      size: size,
      color: color ?? category.accentColor,
    );
  }
}
