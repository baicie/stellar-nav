import 'package:flutter/material.dart';

abstract final class AppColors {
  static const voidBlack = Color(0xff05080c);
  static const space = Color(0xff091018);
  static const panel = Color(0xf20b141d);
  static const panelStrong = Color(0xff0e1923);
  static const line = Color(0xff22313d);
  static const lineBright = Color(0xff38505f);
  static const text = Color(0xffeef7f7);
  static const textMuted = Color(0xff91a5ad);
  static const textDim = Color(0xff60757e);
  static const cyan = Color(0xff5eead4);
  static const cyanStrong = Color(0xff22c7bd);
  static const amber = Color(0xffffc857);
  static const coral = Color(0xffff766d);
  static const green = Color(0xff72d8a5);
  static const blue = Color(0xff67a9ff);
  static const violet = Color(0xffa99cff);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadii {
  static const small = 4.0;
  static const medium = 8.0;
}

abstract final class AppSizes {
  static const iconButton = 48.0;
  static const compactControl = 38.0;
  static const desktopDock = 392.0;
  static const maxBottomPanel = 620.0;
}
