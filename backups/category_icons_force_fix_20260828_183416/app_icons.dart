import 'package:flutter/material.dart';

abstract final class AppIcons {
  static const profile = Icons.person_outline;
  static const location = Icons.location_on_outlined;
  static const search = Icons.search;
  static const settings = Icons.tune_outlined;

  static const coffee = Icons.coffee_outlined;
  static const restaurant = Icons.restaurant_outlined;
  static const foodTruck = Icons.local_shipping_outlined;
  static const bar = Icons.local_bar_outlined;

  static const camera = Icons.photo_camera_outlined;
  static const gallery = Icons.photo_library_outlined;

  static const edit = Icons.edit_outlined;
  static const delete = Icons.delete_outline;
  static const back = Icons.arrow_back_ios_new;
  static const forward = Icons.arrow_forward_ios;

  static const calendar = Icons.calendar_today_outlined;
  static const star = Icons.star_outline;
  static const check = Icons.check;
  static const close = Icons.close;

  static const Map<String, IconData> categoryIcons = {
    'coffee_outlined': Icons.coffee_outlined,
    'restaurant_outlined': Icons.restaurant_outlined,
    'local_shipping_outlined': Icons.local_shipping_outlined,
    'local_bar_outlined': Icons.local_bar_outlined,
    'coffee_cart': Icons.storefront_outlined,

    // קטגוריות חדשות
    'icecream_outlined': Icons.icecream_outlined,
    'bakery_dining_outlined': Icons.bakery_dining_outlined,
    'fastfood_outlined': Icons.fastfood_outlined,
  };

  static IconData categoryIcon(String? name) {
    if (name == null || name.trim().isEmpty) {
      return Icons.place_outlined;
    }

    return categoryIcons[name.trim()] ?? Icons.place_outlined;
  }
}
