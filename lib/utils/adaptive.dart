import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

bool isIPad(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

class Adaptive {
  Adaptive._();

  static bool of(BuildContext context) => isIPad(context);

  static double w(BuildContext context, num value) =>
      isIPad(context) ? value.w : value.toDouble();

  static double h(BuildContext context, num value) =>
      isIPad(context) ? value.h : value.toDouble();

  static double sp(BuildContext context, num value) =>
      isIPad(context) ? value.sp : value.toDouble();

  static double r(BuildContext context, num value) =>
      isIPad(context) ? value.r : value.toDouble();
}
