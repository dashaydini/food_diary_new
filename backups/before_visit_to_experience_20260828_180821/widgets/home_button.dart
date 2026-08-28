import 'package:flutter/material.dart';

import '../screens/category_selection_screen.dart';
import '../theme/colors.dart';

class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'בית',
      icon: const Icon(
        Icons.home_outlined,
        color: AppColors.brass,
        size: 23,
      ),
      onPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const CategorySelectionScreen(),
          ),
          (route) => false,
        );
      },
    );
  }
}
