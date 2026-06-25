import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/services/local_model_service.dart';
import 'package:vidlang/services/model_download_service.dart';
import 'package:vidlang/theme/theme.dart';

/// 模型下载弹窗
/// 当用户没有本地模型或需要更新时显示
class ModelDownloadDialog extends StatefulWidget {
  /// 是否强制显示（忽略用户关闭操作）
  final bool forceShow;
  
  /// 下载完成后的回调
  final VoidCallback? onDownloadComplete;
  
  /// 取消后的回调
  final VoidCallback? onCancel;

  const ModelDownloadDialog({
    super.key,
    this.forceShow = false,
    this.onDownloadComplete,
    this.onCancel,
  });

  /// 显示模型下载弹窗
  static Future<bool> show(
    BuildContext context, {
    bool forceShow = false,
    VoidCallback? onDownloadComplete,
    VoidCallback? onCancel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !forceShow,
      builder: (_) => ModelDownloadDialog(
        forceShow: forceShow,
        onDownloadComplete: onDownloadComplete,
        onCancel: onCancel,
      ),
    );
    return result ?? false;
  }

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  final ModelDownloadService _downloadService = ModelDownloadService.instance;
  final LocalModelService _localModelService = LocalModelService.instance;
  
  ModelConfigResponse? _config;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isCompleted = false;
  String? _error;
  
  // 下载进度
  final Map<String, double> _progress = {};
  final Map<String, String> _status = {};
  
  // 当前下载的模型
  String? _currentDownloadingModel;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      _config = await _downloadService.getModelConfig();
      
      // 初始化进度
      for (final modelType in _config!.models.keys) {
        _progress[modelType] = 0.0;
        _status[modelType] = '等待下载';
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startDownload() async {
    if (_config == null || _isDownloading) return;
    
    setState(() {
      _isDownloading = true;
      _error = null;
    });
    
    try {
      for (final entry in _config!.models.entries) {
        final modelType = entry.key;
        final modelInfo = entry.value;
        
        if (modelInfo.required) {
          setState(() {
            _currentDownloadingModel = modelType;
            _status[modelType] = '下载中...';
          });
          
          await _downloadService.downloadModel(
            modelType: modelType,
            url: modelInfo.url,
            expectedSize: modelInfo.size,
            version: modelInfo.version,
            onProgress: (progress, speed) {
              setState(() {
                _progress[modelType] = progress;
                if (speed.isNotEmpty) {
                  _status[modelType] = '下载中... $speed';
                }
              });
            },
            onComplete: () {
              setState(() {
                _status[modelType] = '下载完成';
                _progress[modelType] = 1.0;
              });
            },
            onError: (error) {
              setState(() {
                _status[modelType] = '下载失败';
                _error = '模型 $modelType 下载失败: $error';
              });
            },
          );
        }
      }
      
      // 刷新模型状态
      await _localModelService.reset();
      
      setState(() {
        _isDownloading = false;
        _isCompleted = true;
        _currentDownloadingModel = null;
      });
      
      // 延迟关闭弹窗
      await Future.delayed(Duration(seconds: 1));
      
      if (mounted) {
        widget.onDownloadComplete?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _error = e.toString();
        _currentDownloadingModel = null;
      });
    }
  }

  void _cancel() {
    widget.onCancel?.call();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceShow && !_isDownloading,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          width: 320.w,
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              _buildHeader(),
              SizedBox(height: 16.h),
              
              // 内容
              if (_isLoading)
                _buildLoading()
              else if (_error != null && !_isDownloading)
                _buildError()
              else
                _buildContent(),
              
              SizedBox(height: 20.h),
              
              // 按钮
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          _isCompleted ? Icons.check_circle : Icons.cloud_download,
          color: _isCompleted ? Colors.green : AppColors.primary,
          size: 24.w,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            _isCompleted ? '下载完成' : '需要下载AI模型',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 100.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.w,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 12.h),
            Text(
              '正在获取模型配置...',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20.w),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_config == null) return SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 说明文字
        Text(
          '使用AI功能（翻译、对话、出题等）需要下载本地模型。下载后可完全离线使用。',
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        SizedBox(height: 16.h),
        
        // 模型列表
        ..._config!.models.entries.map((entry) {
          final modelType = entry.key;
          final modelInfo = entry.value;
          final progress = _progress[modelType] ?? 0.0;
          final status = _status[modelType] ?? '';
          final isCurrentDownloading = _currentDownloadingModel == modelType;
          
          return _buildModelItem(
            modelType: modelType,
            name: modelInfo.displayName,
            size: modelInfo.size,
            version: modelInfo.version,
            progress: progress,
            status: status,
            isDownloading: isCurrentDownloading,
            isCompleted: progress >= 1.0,
          );
        }),
      ],
    );
  }

  Widget _buildModelItem({
    required String modelType,
    required String name,
    required String size,
    required String version,
    required double progress,
    required String status,
    required bool isDownloading,
    required bool isCompleted,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isDownloading 
              ? AppColors.primary.withValues(alpha: 0.5)
              : isCompleted 
                  ? Colors.green.withValues(alpha: 0.5)
                  : AppColors.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.smart_toy,
                color: isCompleted ? Colors.green : AppColors.primary,
                size: 16.w,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Text(
                size,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Text(
                'v$version',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDownloading 
                        ? AppColors.primary 
                        : isCompleted 
                            ? Colors.green 
                            : AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (isDownloading || progress > 0) ...[
            SizedBox(height: 8.h),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.outline.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? Colors.green : AppColors.primary,
              ),
              minHeight: 4.h,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        // 取消按钮（非强制模式下显示）
        if (!widget.forceShow && !_isDownloading)
          Expanded(
            child: TextButton(
              onPressed: _cancel,
              child: Text(
                '稍后再说',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        
        if (!widget.forceShow && !_isDownloading)
          SizedBox(width: 12.w),
        
        // 下载按钮
        Expanded(
          child: ElevatedButton(
            onPressed: _isDownloading || _isCompleted 
                ? null 
                : _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              _isCompleted 
                  ? '完成' 
                  : _isDownloading 
                      ? '下载中...' 
                      : '开始下载',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
