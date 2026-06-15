class WordBookFilter {
  final String? status;
  final String? tagCode;
  final String? contentType;
  final String keyword;

  const WordBookFilter({
    this.status,
    this.tagCode,
    this.contentType,
    this.keyword = '',
  });
}

class WordBookNavItem {
  final String code;
  final String label;
  final int count;
  final String status;
  final String? tagCode;

  const WordBookNavItem({
    required this.code,
    required this.label,
    required this.count,
    required this.status,
    this.tagCode,
  });
}

class WordBookTestResult {
  final String wordBookCode;
  final bool correct;
  final DateTime reviewedAt;

  const WordBookTestResult({
    required this.wordBookCode,
    required this.correct,
    required this.reviewedAt,
  });
}
