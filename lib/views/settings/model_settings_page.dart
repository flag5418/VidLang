import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/services/local_model_service.dart';
import 'package:vidlang/services/model_download_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/widgets/model_download_dialog.dart';

/// 模型设置页面
/// 管理本地模型的下载、更新和镜像配置
class ModelSettingsPage extends StatefulWidget {
  const ModelSettingsPage({super.key});

  @override
  State<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends State<ModelSettingsPage> {
  final ModelDownloadService _downloadService = ModelDownloadService.instance;
  final LocalModelService _localModelService = LocalModelService.instance;
  
  String _selectedMirror = 'https://hf-mirror.com';
  bool _isLoading = true;
  LocalModelStatus _modelStatus = LocalModelStatus.unknown;
  
  // 各模型的下载状态
  final Map<String, bool> _modelDownloaded = {};
  final Map<String, String> _modelVersions = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      
      // 加载镜像设置
      final prefs = await SharedPreferences.getInstance();
      _selectedMirror = prefs.getString('model_mirror') ?? 'https://hf-mirror.com';
      
      // 检查模型状态
      _modelStatus = await _localModelService.checkModelsStatus();
      
      // 加载各模型状态
      for (final modelType in ['tts', 'stt']) {
        _modelDownloaded[modelType] = await _downloadService.isModelDownloaded(modelType);
        _modelVersions[modelType] = prefs.getString('model_version_$modelType') ?? '未安装';
      }
      
      // 加载远程配置
      try {
        await _downloadService.getModelConfig(customMirror: _selectedMirror);
      } catch (e) {
        debugPrint('加载远程配置失败: $e');
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('加载设置失败: $e');
    }
  }

  Future<void> _saveMirror(String mirror) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model_mirror', mirror);
    setState(() => _selectedMirror = mirror);
    
    // 刷新配置
    try {
      await _downloadService.getModelConfig(customMirror: mirror);
    } catch (e) {
      debugPrint('刷新配置失败: $e');
    }
  }

  Future<void> _downloadAllModels() async {
    final result = await ModelDownloadDialog.show(
      context,
      onDownloadComplete: () {
        _loadSettings(); // 刷新状态
      },
    );
    
    if (result == true) {
      // 下载完成，刷新状态
      await _localModelService.reset();
      await _loadSettings();
    }
  }

  Future<void> _deleteModel(String modelType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除此模型吗？删除后需要重新下载才能使用相关功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _downloadService.deleteModel(modelType);
      await _loadSettings();
    }
  }

  Future<void> _deleteAllModels() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除所有模型'),
        content: Text('确定要删除所有本地模型吗？删除后需要重新下载才能使用AI功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('全部删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _downloadService.deleteAllModels();
      await _localModelService.reset();
      await _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('模型设置'),
        backgroundColor: AppColors.surface,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 模型状态卡片
                  _buildStatusCard(),
                  SizedBox(height: 16.h),
                  
                  // 模型列表
                  _buildModelList(),
                  SizedBox(height: 16.h),
                  
                  // 镜像设置
                  _buildMirrorSettings(),
                  SizedBox(height: 16.h),
                  
                  // 操作按钮
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final color = _modelStatus.canUseAiFeatures ? Colors.green : AppColors.error;
    final icon = _modelStatus.canUseAiFeatures ? Icons.check_circle : Icons.warning;
    
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _modelStatus.displayName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _modelStatus.description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelList() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已安装模型',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            
            _buildModelItem(
              modelType: 'tts',
              name: 'Piper TTS',
              description: '语音合成',
              isDownloaded: _modelDownloaded['tts'] ?? false,
              version: _modelVersions['tts'] ?? '未安装',
            ),
            Divider(height: 1),
            _buildModelItem(
              modelType: 'stt',
              name: 'Whisper',
              description: '语音识别',
              isDownloaded: _modelDownloaded['stt'] ?? false,
              version: _modelVersions['stt'] ?? '未安装',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelItem({
    required String modelType,
    required String name,
    required String description,
    required bool isDownloaded,
    required String version,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Icon(
            isDownloaded ? Icons.check_circle : Icons.download,
            color: isDownloaded ? Colors.green : AppColors.onSurfaceVariant,
            size: 20.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isDownloaded) ...[
            Text(
              'v$version',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(width: 8.w),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20.w),
              onPressed: () => _deleteModel(modelType),
              color: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMirrorSettings() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '下载镜像',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '选择模型下载源，国内用户推荐使用镜像站',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 12.h),
            
            _buildMirrorOption(
              name: 'hf-mirror.com（推荐）',
              url: 'https://hf-mirror.com',
              description: '国内最稳定，速度快',
            ),
            _buildMirrorOption(
              name: '上海交大镜像',
              url: 'https://mirror.sjtu.edu.cn/huggingface',
              description: '学术镜像，速度快',
            ),
            _buildMirrorOption(
              name: 'ModelScope（阿里）',
              url: 'https://huggingface.modelscope.cn',
              description: '阿里维护，国产模型首选',
            ),
            _buildMirrorOption(
              name: 'HuggingFace 官方',
              url: 'https://huggingface.co',
              description: '国际源，国内速度较慢',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMirrorOption({
    required String name,
    required String url,
    required String description,
  }) {
    final isSelected = _selectedMirror == url;
    
    return ListTile(
      title: Text(
        name,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          fontSize: 12.sp,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      leading: Radio<String>(
        value: url,
        groupValue: _selectedMirror,
        onChanged: (value) {
          if (value != null) {
            _saveMirror(value);
          }
        },
        activeColor: AppColors.primary,
      ),
      contentPadding: EdgeInsets.zero,
      onTap: () => _saveMirror(url),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // 下载/更新按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _downloadAllModels,
            icon: Icon(Icons.cloud_download),
            label: Text(
              _modelStatus.canUseAiFeatures ? '更新模型' : '下载模型',
              style: TextStyle(fontSize: 16.sp),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
        
        if (_modelStatus.canUseAiFeatures) ...[
          SizedBox(height: 12.h),
          // 删除所有模型按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deleteAllModels,
              icon: Icon(Icons.delete_outline, color: AppColors.error),
              label: Text(
                '删除所有模型',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
