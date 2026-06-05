import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/models/error_log.dart';
import 'package:vidlang/services/database_service.dart';

class AppGuard {
  static Future<T?> run<T>(
    BuildContext context, {
    required Future<T> Function() action,
    String title = '出现异常',
    String tag = 'APP',
    String? successMessage,
    Map<String, dynamic>? extra,
    bool showDialog = true,
  }) async {
    try {
      final result = await action();
      if (successMessage != null && context.mounted) {
        TDMessage.showMessage(
          context: context,
          content: successMessage,
          theme: MessageTheme.success,
          duration: 2500,
          visible: true,
        );
      }
      return result;
    } catch (e, st) {
      logger.error(title, tag: tag, error: e, stackTrace: st, extra: extra);

      try {
        final userCode = await DatabaseService.getCurrentUserCode();
        final log = ErrorLog(
          level: 'error',
          tag: tag,
          message: title,
          error: e.toString(),
          stackTrace: st.toString(),
          extra: extra == null ? null : jsonEncode(extra),
        );
        log.userCode = userCode;
        log.createdBy = userCode;
        log.updatedBy = userCode;
        await DatabaseService.insert(log);
      } catch (persistError, persistStack) {
        logger.error(
          'persist error_log failed',
          tag: 'ERROR_LOG',
          error: persistError,
          stackTrace: persistStack,
          extra: {'originTag': tag},
        );
      }

      if (showDialog && context.mounted) {
        await showGeneralDialog(
          context: context,
          pageBuilder: (buildContext, animation, secondaryAnimation) {
            return TDAlertDialog.vertical(
              title: title,
              content: e.toString(),
              buttons: [
                TDDialogButtonOptions(
                  title: '知道了',
                  theme: TDButtonTheme.primary,
                  action: () => Navigator.pop(buildContext),
                ),
              ],
            );
          },
        );
      }

      return null;
    }
  }
}

