import 'package:flutter/material.dart';

class NavigationHelper {
  static void pushNamed(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  static void pushNamedAndRemoveUntil(BuildContext context, String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  static void pop(BuildContext context) {
    Navigator.of(context).pop();
  }
}