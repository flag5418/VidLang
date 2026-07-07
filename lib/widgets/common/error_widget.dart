import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
// import 'package:hugeicons/hugeicons.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  final String? title;
  final bool showRetry;

  const ErrorDisplayWidget({
    Key? key,
    required this.error,
    this.onRetry,
    this.title,
    this.showRetry = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Adaptive.w(context, 24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.error,
              size: Adaptive.sp(context, 64),
              color: TDTheme.of(context).errorNormalColor,
            ),
            SizedBox(height: Adaptive.h(context, 16)),
            Text(
              title ?? '出错了',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 18),
                fontWeight: FontWeight.w600,
                color: TDTheme.of(context).fontGyColor1,
              ),
            ),
            SizedBox(height: Adaptive.h(context, 8)),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 14),
                color: TDTheme.of(context).fontGyColor3,
                height: 1.4,
              ),
            ),
            if (showRetry && onRetry != null) ...[
              SizedBox(height: Adaptive.h(context, 24)),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}