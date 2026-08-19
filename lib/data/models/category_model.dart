import 'package:flutter/material.dart';

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.userId,
    required this.key,
    required this.name,
    this.iconKey = 'custom',
    this.parentKey,
  });

  static const _builtinIconKeys = <String>{
    'activities',
    'animals',
    'colors',
    'drinks',
    'drinks_cold',
    'drinks_dairy',
    'drinks_hot',
    'family',
    'feelings',
    'food',
    'food_dessert',
    'food_fruits',
    'food_meals',
    'food_vegetables',
    'greetings',
    'health_safety',
    'hobbies',
    'needs',
    'places',
    'responses',
    'school',
    'technology',
    'transportation',
  };

  final int id;
  final int userId;
  final String key;
  final String name;
  final String iconKey;
  final String? parentKey;

  bool get isTopLevel => parentKey == null || parentKey!.trim().isEmpty;

  String get resolvedIconKey {
    if (iconKey != 'custom' && _builtinIconKeys.contains(iconKey)) {
      return iconKey;
    }
    if (_builtinIconKeys.contains(key)) return key;
    return 'custom';
  }

  IconData get icon {
    switch (resolvedIconKey) {
      case 'feelings':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'food_fruits':
        return Icons.apple_rounded;
      case 'food_vegetables':
        return Icons.grass_rounded;
      case 'food_dessert':
        return Icons.cake_rounded;
      case 'food_meals':
        return Icons.ramen_dining_rounded;
      case 'drinks':
        return Icons.local_cafe_rounded;
      case 'drinks_hot':
        return Icons.coffee_rounded;
      case 'drinks_cold':
        return Icons.ac_unit_rounded;
      case 'drinks_dairy':
        return Icons.local_drink_rounded;
      case 'activities':
        return Icons.celebration_rounded;
      case 'animals':
        return Icons.pets_rounded;
      case 'colors':
        return Icons.palette_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'greetings':
        return Icons.waving_hand_rounded;
      case 'health_safety':
        return Icons.health_and_safety_rounded;
      case 'hobbies':
        return Icons.interests_rounded;
      case 'needs':
        return Icons.pan_tool_alt_rounded;
      case 'places':
        return Icons.location_on_rounded;
      case 'responses':
        return Icons.forum_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'technology':
        return Icons.devices_rounded;
      case 'transportation':
        return Icons.directions_car_filled_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  Color get accentColor {
    final paletteKey = _builtinIconKeys.contains(key)
        ? key
        : (_builtinIconKeys.contains(resolvedIconKey) ? resolvedIconKey : key);
    switch (paletteKey) {
      case 'feelings':
        return const Color(0xFF4A90D9);
      case 'food':
        return const Color(0xFFE85D5D);
      case 'food_fruits':
        return const Color(0xFF43A047);
      case 'food_vegetables':
        return const Color(0xFF7CB342);
      case 'food_dessert':
        return const Color(0xFFEC407A);
      case 'food_meals':
        return const Color(0xFFE85D5D);
      case 'drinks':
        return const Color(0xFF9B59D4);
      case 'drinks_hot':
        return const Color(0xFF8D6E63);
      case 'drinks_cold':
        return const Color(0xFF29B6F6);
      case 'drinks_dairy':
        return const Color(0xFF9B59D4);
      case 'activities':
        return const Color(0xFFF5B942);
      case 'animals':
        return const Color(0xFF5BB88A);
      case 'colors':
        return const Color(0xFFE91E8C);
      case 'family':
        return const Color(0xFFFF7043);
      case 'greetings':
        return const Color(0xFF26A69A);
      case 'health_safety':
        return const Color(0xFFEF5350);
      case 'hobbies':
        return const Color(0xFF8D6E63);
      case 'needs':
        return const Color(0xFF42A5F5);
      case 'places':
        return const Color(0xFF66BB6A);
      case 'responses':
        return const Color(0xFF7E57C2);
      case 'school':
        return const Color(0xFFFFA726);
      case 'technology':
        return const Color(0xFF5C6BC0);
      case 'transportation':
        return const Color(0xFF78909C);
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
        if (parentKey != null) 'parent_category_key': parentKey,
      };

  factory CategoryModel.fromMap(Map<String, Object?> map) {
    return CategoryModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      key: map['category_key'] as String,
      name: map['category_name'] as String,
      iconKey: (map['icon_key'] as String?) ?? 'custom',
      parentKey: map['parent_category_key'] as String?,
    );
  }
}
