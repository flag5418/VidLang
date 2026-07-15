import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:vidlang/models/error_log.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/components/dialogs/app_dialogs.dart';

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
        AppToast.show(context, successMessage, type: ToastType.success);
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
        await AppAlertDialog.show(
          context,
          title: title,
          content: e.toString(),
          buttonText: '知道了',
        );
      }

      return null;
    }
  }
}

