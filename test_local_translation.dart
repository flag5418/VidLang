/// 测试本地翻译模型
/// 运行: dart run test_local_translation.dart
void main() async {
  // WidgetsFlutterBinding.ensureInitialized();

  // print('=== 本地翻译模型测试 ===\n');

  // // 1. 测试 Tokenizer 初始化
  // print('1. 初始化 Tokenizer...');
  // final tokenizer = SentencePieceTokenizer.instance;
  // final tokenizerReady = await tokenizer.initialize();
  // print('   Tokenizer 初始化: ${tokenizerReady ? "成功" : "失败"}');
  // if (!tokenizerReady) {
  //   print('   ❌ Tokenizer 初始化失败，无法继续测试');
  //   return;
  // }
  // print('   词表大小: ${tokenizer._vocabSize}');
  // print('   最大 token 长度: ${tokenizer._maxTokenLength}');

  // // 2. 测试 Tokenizer 编码
  // print('\n2. 测试 Tokenizer 编码...');
  // final testWords = ['apple', 'Wait', 'issue', 'hello', 'the', 'is'];
  // for (final word in testWords) {
  //   final ids = tokenizer.encode(word);
  //   print('   "$word" → token IDs: $ids (长度: ${ids.length})');
  //   if (ids.isEmpty) {
  //     print('   ⚠️ 编码结果为空！');
  //   }
  // }

  // // 3. 测试 LocalTranslationService 初始化
  // print('\n3. 初始化 LocalTranslationService...');
  // final translator = LocalTranslationService.instance;
  // await translator.initialize();
  // print('   翻译服务初始化: ${translator.isInitialized ? "成功" : "失败"}');

  // if (!translator.isInitialized) {
  //   print('   ❌ 翻译服务初始化失败');
  //   return;
  // }

  // // 4. 测试翻译
  // print('\n4. 测试翻译...');
  // final testSentences = [
  //   'apple',
  //   'Wait',
  //   'issue',
  //   'hello world',
  //   'This is a test',
  //   'But what if the folders don\'t have a parent_code?',
  // ];

  // for (final text in testSentences) {
  //   print('\n   输入: "$text"');
  //   try {
  //     final result = await translator.translate(text: text);
  //     print('   输出: "$result"');
  //     if (result.contains('失败') || result.contains('未就绪')) {
  //       print('   ⚠️ 翻译失败！');
  //     }
  //   } catch (e) {
  //     print('   ❌ 异常: $e');
  //   }
  // }

  // print('\n=== 测试完成 ===');
}
