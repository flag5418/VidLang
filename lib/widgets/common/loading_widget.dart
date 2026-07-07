import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/utils/adaptive.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double? size;
  final Color? color;

  const LoadingWidget({
    Key? key,
    this.message,
    this.size,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            color: color ?? Theme.of(context).primaryColor,
          ),
          if (message != null) ...[
            SizedBox(height: Adaptive.h(context, 16)),
            Text(
              message!,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 14),
                color: TDTheme.of(context).fontGyColor3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}