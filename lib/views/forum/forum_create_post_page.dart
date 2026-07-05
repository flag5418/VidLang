import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/forum/forum_category.dart';
import '../../models/forum/forum_post.dart';
import '../../providers/forum_providers.dart';
import 'forum_home_page.dart';

/// 创建帖子页面
class ForumCreatePostPage extends ConsumerStatefulWidget {
  final String? initialPostType;
  final String? initialResourceType;

  const ForumCreatePostPage({
    Key? key,
    this.initialPostType,
    this.initialResourceType,
  }) : super(key: key);

  @override
  ConsumerState<ForumCreatePostPage> createState() => _ForumCreatePostPageState();
}

class _ForumCreatePostPageState extends ConsumerState<ForumCreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _resourceUrlController = TextEditingController();
  final _resourceDescriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  String _selectedPostType = 'discussion';
  String? _selectedResourceType;
  int? _selectedCategoryId;
  bool _isLoading = false;

  final List<String> _postTypes = [
    'discussion',
    'resource', 
    'help',
    'feedback'
  ];

  final List<String> _resourceTypes = [
    'video',
    'audio',
    'article',
    'image',
    'other'
  ];

  final Map<String, String> _postTypeLabels = {
    'discussion': '学习讨论',
    'resource': '资源分享',
    'help': '求助问答',
    'feedback': '反馈建议'
  };

  final Map<String, String> _resourceTypeLabels = {
    'video': '视频',
    'audio': '音频',
    'article': '文章',
    'image': '图片',
    'other': '其他'
  };

  @override
  void initState() {
    super.initState();
    _selectedPostType = widget.initialPostType ?? 'discussion';
    _selectedResourceType = widget.initialResourceType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _resourceUrlController.dispose();
    _resourceDescriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('创建新帖子'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发布'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostTypeSection(),
            SizedBox(height: 24.h),
            _buildTitleField(),
            SizedBox(height: 16.h),
            _buildCategorySelector(),
            SizedBox(height: 16.h),
            _buildContentField(),
            if (_selectedPostType == 'resource') ...[
              SizedBox(height: 16.h),
              _buildResourceSection(),
            ],
            SizedBox(height: 16.h),
            _buildTagsField(),
            SizedBox(height: 32.h),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTypeSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '帖子类型',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            children: _postTypes.map((type) {
              final isSelected = _selectedPostType == type;
              return ChoiceChip(
                label: Text(_postTypeLabels[type]!),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPostType = type;
                      // 重置资源相关字段当类型改变时
                      if (type != 'resource') {
                        _selectedResourceType = null;
                        _resourceUrlController.clear();
                        _resourceDescriptionController.clear();
                      }
                    });
                  }
                },
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          labelText: '帖子标题 *',
          hintText: '请输入一个有吸引力的标题',
          border: InputBorder.none,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[700],
          ),
        ),
        style: TextStyle(fontSize: 16.sp),
        maxLength: 100,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '请输入帖子标题';
          }
          if (value.trim().length < 5) {
            return '标题至少需要5个字符';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categoriesAsync = ref.watch(forumCategoriesProvider);
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: categoriesAsync.when(
        data: (categories) => DropdownButtonFormField<int>(
          value: _selectedCategoryId,
          decoration: InputDecoration(
            labelText: '选择分类 *',
            border: InputBorder.none,
            labelStyle: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[700],
            ),
          ),
          style: TextStyle(fontSize: 16.sp, color: Colors.black87),
          items: categories.map((category) {
            return DropdownMenuItem<int>(
              value: category.id,
              child: Text(category.name),
            );
          }).toList(),
          validator: (value) {
            if (value == null) {
              return '请选择一个分类';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
        ),
        loading: () => Container(
          height: 50.h,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => Text(
          '加载分类失败: $error',
          style: TextStyle(color: Colors.red[600]),
        ),
      ),
    );
  }

  Widget _buildContentField() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        controller: _contentController,
        decoration: InputDecoration(
          labelText: '帖子内容 *',
          hintText: '分享你的想法、知识或问题...',
          border: InputBorder.none,
          alignLabelWithHint: true,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[700],
          ),
        ),
        style: TextStyle(fontSize: 16.sp, height: 1.5),
        maxLines: 8,
        maxLength: 5000,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '请输入帖子内容';
          }
          if (value.trim().length < 10) {
            return '内容至少需要10个字符';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildResourceSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '资源信息',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.amber[800],
            ),
          ),
          SizedBox(height: 12.h),
          // 资源类型选择
          DropdownButtonFormField<String>(
            value: _selectedResourceType,
            decoration: InputDecoration(
              labelText: '资源类型',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              fillColor: Colors.white,
              filled: true,
            ),
            items: _resourceTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text('${_resourceTypeLabels[type]}资源'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedResourceType = value;
              });
            },
          ),
          SizedBox(height: 12.h),
          // 资源链接
          TextFormField(
            controller: _resourceUrlController,
            decoration: InputDecoration(
              labelText: '资源链接',
              hintText: 'https://example.com/resource',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              fillColor: Colors.white,
              filled: true,
            ),
            style: TextStyle(fontSize: 14.sp),
          ),
          SizedBox(height: 12.h),
          // 资源描述
          TextFormField(
            controller: _resourceDescriptionController,
            decoration: InputDecoration(
              labelText: '资源描述',
              hintText: '简要描述这个资源的内容和价值',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              fillColor: Colors.white,
              filled: true,
            ),
            style: TextStyle(fontSize: 14.sp),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTagsField() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        controller: _tagsController,
        decoration: InputDecoration(
          labelText: '标签 (可选)',
          hintText: '用逗号分隔多个标签，如: Flutter, Dart, 教程',
          border: InputBorder.none,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[700],
          ),
        ),
        style: TextStyle(fontSize: 16.sp),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '发布中...',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                '发布帖子',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      _showErrorMessage('请选择一个分类');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 处理标签
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // 构建帖子数据
      final postData = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category_id': _selectedCategoryId!,
        'post_type': _selectedPostType,
        if (_selectedResourceType != null) 'resource_type': _selectedResourceType,
        if (_resourceUrlController.text.isNotEmpty) 'resource_url': _resourceUrlController.text.trim(),
        if (_resourceDescriptionController.text.isNotEmpty) 'resource_description': _resourceDescriptionController.text.trim(),
        if (tags.isNotEmpty) 'tags': tags,
      };

      // 调用模拟API创建帖子
      await _mockCreatePost(postData);

      // 成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8.w),
                const Text('帖子发布成功！'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // 返回论坛主页
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ 发布帖子失败: $e');
      _showErrorMessage('发布失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _mockCreatePost(Map<String, dynamic> postData) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(seconds: 2));
    
    // 模拟创建帖子的逻辑
    print('📝 创建帖子:');
    print('   标题: ${postData['title']}');
    print('   类型: ${postData['post_type']}');
    print('   分类ID: ${postData['category_id']}');
    print('   内容长度: ${postData['content'].length}');
    if (postData['resource_type'] != null) {
      print('   资源类型: ${postData['resource_type']}');
    }
    if (postData['tags'] != null) {
      print('   标签: ${postData['tags']}');
    }
    
    // 模拟随机失败率（测试错误处理）
    if (DateTime.now().millisecond < 100) {
      throw Exception('网络连接失败');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8.w),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}