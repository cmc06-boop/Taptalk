import 'package:flutter/material.dart';

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.userId,
    required this.key,
    required this.name,
    this.iconKey = 'custom',
  });

  final int id;
  final int userId;
  final String key;
  final String name;
  final String iconKey;

  IconData get icon {
    switch (iconKey) {
      case 'feelings':
        return Icons.volunteer_activism_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'drinks':
        return Icons.local_drink_outlined;
      case 'activities':
        return Icons.landscape_outlined;
      case 'animals':
        return Icons.pets_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  Color get accentColor {
    switch (iconKey) {
      case 'feelings':
        return const Color(0xFF4A90D9);
      case 'food':
        return const Color(0xFFE85D5D);
      case 'drinks':
        return const Color(0xFF9B59D4);
      case 'activities':
        return const Color(0xFFF5B942);
      case 'animals':
        return const Color(0xFF5BB88A);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'category_key': key,
        'category_name': name,
        'icon_key': iconKey,
      };

  factory CategoryModel.fromMap(Map<String, Object?> map) {
    return CategoryModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      key: map['category_key'] as String,
      name: map['category_name'] as String,
      iconKey: (map['icon_key'] as String?) ?? 'custom',
    );
  }
}
