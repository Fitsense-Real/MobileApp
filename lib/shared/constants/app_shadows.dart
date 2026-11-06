import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 25,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x332563EB),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}