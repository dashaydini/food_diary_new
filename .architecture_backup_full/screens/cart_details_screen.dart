import 'package:flutter/material.dart';

import '../models/coffee_cart.dart';
import 'coffee_cart/coffee_cart_details_screen.dart';

class CartDetailsScreen extends StatelessWidget {
  final CoffeeCart cart;
  final bool myContentOnly;

  const CartDetailsScreen({
    super.key,
    required this.cart,
    this.myContentOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return CoffeeCartDetailsScreen(
      cart: cart,
      myContentOnly: myContentOnly,
    );
  }
}
