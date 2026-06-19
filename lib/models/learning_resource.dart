/// 学习资源渠道模型
///
/// 用于在 App 内引导用户合法、高效地获取英文学习资料。
/// 按地区区分可用性，所有链接需经过验证。
class LearningResource {
  final String id;
  final String name;
  final String description;
  final ResourceCategory category;
  final String url;

  /// 资源媒介类型
  final ResourceType type;

  /// 许可证类型（如 CC BY-NC-ND 4.0 / 公共领域 / 个人学习免费）
  final String license;

  /// 是否允许下载用于个人学习
  final bool downloadable;

  /// 国内是否可访问（无需翻墙）
  final bool accessibleInChina;

  /// 是否可商用
  final bool commercialUse;

  /// 备用地址（国内镜像等）
  final String? alternativeUrl;

  /// 使用提示
  final String? tip;

  const LearningResource({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.url,
    required this.type,
    required this.license,
    required this.downloadable,
    required this.accessibleInChina,
    this.commercialUse = false,
    this.alternativeUrl,
    this.tip,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category.name,
        'url': url,
        'type': type.name,
        'license': license,
        'downloadable': downloadable,
        'accessibleInChina': accessibleInChina,
        'commercialUse': commercialUse,
        'alternativeUrl': alternativeUrl,
        'tip': tip,
      };
}

/// 资源大类
enum ResourceCategory {
  /// 公版书 / 经典文学
  publicDomain,

  /// 新闻资讯
  news,

  /// 播客 / 广播
  podcast,

  /// 教育课程
  course,

  /// 演讲 / 访谈
  talk,

  /// 有声书
  audiobook,

  /// 字幕 / 文本对齐
  subtitle,
}

/// 资源媒介类型
enum ResourceType {
  video,
  audio,
  article,
  mixed,
}

/// 经过验证的学习资源清单
///
/// 维护说明：
/// - 所有链接需在国内外分别测试可访问性后再收录
/// - 许可证信息以官方页面为准
/// - 国内访问状态可能随时间变化，建议定期复测
class VerifiedResources {
  /// ============ 视频资源 ============

  static const tedTalks = LearningResource(
    id: 'ted-talks',
    name: 'TED Talks',
    description: '高质量英文演讲，配有双语字幕与逐字稿，适合中高级学习者',
    category: ResourceCategory.talk,
    url: 'https://www.ted.com/talks',
    type: ResourceType.video,
    license: 'CC BY-NC-ND 4.0',
    downloadable: false,
    accessibleInChina: true,
    commercialUse: false,
    alternativeUrl: 'https://open.163.com/ted/',
    tip: '须使用官方播放器；字幕可在每条演讲页下载。国内访问不稳定时可用网易镜像',
  );

  static const khanAcademy = LearningResource(
    id: 'khan-academy',
    name: 'Khan Academy',
    description: '可汗学院免费课程，涵盖多学科，适合学术英语',
    category: ResourceCategory.course,
    url: 'https://www.khanacademy.org/',
    type: ResourceType.video,
    license: 'CC BY-NC-SA',
    downloadable: true,
    accessibleInChina: false,
    commercialUse: false,
    tip: '视频托管于 YouTube，国内无法直接访问',
  );

  static const cgtn = LearningResource(
    id: 'cgtn',
    name: 'CGTN',
    description: '中国国际电视台英文频道，国内稳定访问的新闻视频',
    category: ResourceCategory.news,
    url: 'https://www.cgtn.com/',
    type: ResourceType.video,
    license: '个人观看免费',
    downloadable: false,
    accessibleInChina: true,
    commercialUse: false,
  );

  /// ============ 音频资源 ============

  static const librivox = LearningResource(
    id: 'librivox',
    name: 'LibriVox',
    description: '公版书有声书，完全免费可下载，国内外均可访问',
    category: ResourceCategory.audiobook,
    url: 'https://librivox.org/',
    type: ResourceType.audio,
    license: '公共领域 (Public Domain)',
    downloadable: true,
    accessibleInChina: true,
    commercialUse: true,
    alternativeUrl: 'https://archive.org/details/librivoxaudio',
    tip: '推荐首选：合法可下载、可商用、国内外可访问',
  );

  static const voaLearningEnglish = LearningResource(
    id: 'voa-learning-english',
    name: 'VOA Learning English',
    description: '美国之音慢速英语，适合初中级学习者',
    category: ResourceCategory.news,
    url: 'https://learningenglish.voanews.com/',
    type: ResourceType.mixed,
    license: '个人学习免费',
    downloadable: true,
    accessibleInChina: false,
    commercialUse: false,
    tip: '提供 MP3 下载；国内访问不稳定',
  );

  static const bbc6Minute = LearningResource(
    id: 'bbc-6-minute',
    name: 'BBC 6 Minute English',
    description: 'BBC 六分钟英语，每期含 MP3 与逐字稿',
    category: ResourceCategory.podcast,
    url: 'https://www.bbc.co.uk/learningenglish/english/features/6-minute-english',
    type: ResourceType.audio,
    license: '个人学习免费',
    downloadable: true,
    accessibleInChina: false,
    commercialUse: false,
    tip: '每期可下载 MP3 + PDF 逐字稿；国内被墙',
  );

  static const nprPodcasts = LearningResource(
    id: 'npr-podcasts',
    name: 'NPR Podcasts',
    description: '美国国家公共广播电台播客，语速自然',
    category: ResourceCategory.podcast,
    url: 'https://www.npr.org/podcasts/',
    type: ResourceType.audio,
    license: '个人收听免费',
    downloadable: true,
    accessibleInChina: false,
    commercialUse: false,
    tip: '通过官方 RSS 订阅下载；国内访问不稳定',
  );

  static const listenNotes = LearningResource(
    id: 'listen-notes',
    name: 'Listen Notes',
    description: '播客搜索引擎，可查找英文播客 RSS 链接',
    category: ResourceCategory.podcast,
    url: 'https://www.listennotes.com/',
    type: ResourceType.audio,
    license: '依赖各播客许可',
    downloadable: false,
    accessibleInChina: true,
    commercialUse: false,
    tip: '搜索播客后获取 RSS feed，导入播客客户端下载',
  );

  /// ============ 文章/文本资源 ============

  static const projectGutenberg = LearningResource(
    id: 'project-gutenberg',
    name: 'Project Gutenberg',
    description: '公版电子书库，超过 7 万册经典英文著作，可下载 TXT/EPUB',
    category: ResourceCategory.publicDomain,
    url: 'https://www.gutenberg.org/',
    type: ResourceType.article,
    license: '公共领域 (Public Domain)',
    downloadable: true,
    accessibleInChina: true,
    commercialUse: true,
    alternativeUrl: 'https://www.gutenberg.org/ebooks/search/',
    tip: '推荐首选：合法可下载、可商用、国内外可访问',
  );

  static const newsInLevels = LearningResource(
    id: 'news-in-levels',
    name: 'News in Levels',
    description: '分级英语新闻，分三个难度等级，配有音频',
    category: ResourceCategory.news,
    url: 'https://www.newsinlevels.com/',
    type: ResourceType.mixed,
    license: '个人学习免费',
    downloadable: false,
    accessibleInChina: true,
    commercialUse: false,
  );

  static const breakingNewsEnglish = LearningResource(
    id: 'breaking-news-english',
    name: 'Breaking News English',
    description: '分级新闻英语教学资源，含 MP3 与练习',
    category: ResourceCategory.news,
    url: 'https://breakingnewsenglish.com/',
    type: ResourceType.mixed,
    license: '教育使用',
    downloadable: true,
    accessibleInChina: true,
    commercialUse: false,
  );

  static const commonLit = LearningResource(
    id: 'commonlit',
    name: 'CommonLit',
    description: '免费分级阅读资源库，适合系统性阅读训练',
    category: ResourceCategory.course,
    url: 'https://www.commonlit.org/',
    type: ResourceType.article,
    license: '教育免费',
    downloadable: false,
    accessibleInChina: true,
    commercialUse: false,
    tip: '需注册教师账号',
  );

  static const chinaDaily = LearningResource(
    id: 'china-daily',
    name: 'China Daily',
    description: '中国日报英文版，国内稳定访问的英文新闻',
    category: ResourceCategory.news,
    url: 'https://www.chinadaily.com.cn/',
    type: ResourceType.article,
    license: '个人阅读免费',
    downloadable: false,
    accessibleInChina: true,
    commercialUse: false,
  );

  static const twentyFirstCentury = LearningResource(
    id: '21st-century',
    name: '21st Century 英文报',
    description: '国内英文学习报纸，适合学生水平',
    category: ResourceCategory.news,
    url: 'https://www.i21st.cn/',
    type: ResourceType.article,
    license: '个人学习',
    downloadable: false,
    accessibleInChina: true,
    commercialUse: false,
  );

  /// ============ 字幕资源 ============

  static const amara = LearningResource(
    id: 'amara',
    name: 'Amara',
    description: '开放字幕协作平台，可下载 CC 许可字幕',
    category: ResourceCategory.subtitle,
    url: 'https://amara.org/',
    type: ResourceType.article,
    license: 'CC 许可字幕',
    downloadable: true,
    accessibleInChina: false,
    commercialUse: false,
  );

  /// ============ 全量清单 ============

  /// 所有已验证资源
  static const List<LearningResource> all = [
    // 视频
    tedTalks,
    khanAcademy,
    cgtn,
    // 音频
    librivox,
    voaLearningEnglish,
    bbc6Minute,
    nprPodcasts,
    listenNotes,
    // 文章
    projectGutenberg,
    newsInLevels,
    breakingNewsEnglish,
    commonLit,
    chinaDaily,
    twentyFirstCentury,
    // 字幕
    amara,
  ];

  /// 按地区筛选可用资源
  ///
  /// [inChina] 为 true 时返回国内可访问的资源
  static List<LearningResource> byRegion(bool inChina) {
    return all.where((r) => !inChina || r.accessibleInChina).toList();
  }

  /// 按媒介类型筛选
  static List<LearningResource> byType(ResourceType type) {
    return all.where((r) => r.type == type).toList();
  }

  /// 按大类筛选
  static List<LearningResource> byCategory(ResourceCategory category) {
    return all.where((r) => r.category == category).toList();
  }

  /// 推荐资源（最优先）
  ///
  /// 综合合法性、可下载性、国内外可访问性
  static const List<LearningResource> recommended = [
    librivox,
    projectGutenberg,
    tedTalks,
    newsInLevels,
    breakingNewsEnglish,
  ];
}
