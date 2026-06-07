/// 英文文本分词工具
///
/// 用于将没有空格的英文文本拆分成单词列表。
/// 使用贪心最长匹配算法 + 常用词表实现。
class EnglishSegmenter {
  EnglishSegmenter._();

  /// 对文本进行分词
  /// 如果文本已有空格分隔，直接按空格拆分
  /// 如果文本没有空格（单词粘连），使用最长匹配算法拆分
  static List<String> segment(String text) {
    if (text.isEmpty) return [];

    // 如果文本已有空格，直接拆分
    final spaceSplit = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (spaceSplit.length > 1) return spaceSplit;

    // 单词粘连情况：使用贪心最长匹配
    final result = <String>[];
    final lower = text.toLowerCase();
    int i = 0;

    while (i < text.length) {
      // 跳过非字母字符（保留为单独 token）
      if (!_isLetter(text[i])) {
        result.add(text[i]);
        i++;
        continue;
      }

      // 从最长开始匹配（最大单词长度 15）
      int bestLen = 1;
      for (int len = _maxWordLen; len >= 2; len--) {
        if (i + len > text.length) continue;
        final candidate = lower.substring(i, i + len);
        if (_commonWords.contains(candidate)) {
          bestLen = len;
          break;
        }
      }

      // 如果单字符也是常见词或没有更好匹配
      if (bestLen == 1 && _commonWords.contains(lower[i])) {
        bestLen = 1;
      }

      result.add(text.substring(i, i + bestLen));
      i += bestLen;
    }

    return result;
  }

  static bool _isLetter(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  static const int _maxWordLen = 15;

  /// 常用英语词表（约 600 词，覆盖日常字幕高频词）
  static final Set<String> _commonWords = {
    // 冠词/代词/介词/连词
    'a', 'an', 'the', 'i', 'me', 'my', 'we', 'us', 'our', 'you', 'your',
    'he', 'him', 'his', 'she', 'her', 'it', 'its', 'they', 'them', 'their',
    'this', 'that', 'these', 'those', 'who', 'whom', 'what', 'which',
    'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'up',
    'about', 'into', 'through', 'during', 'before', 'after', 'above',
    'below', 'between', 'under', 'over', 'out', 'off', 'down', 'near',
    'and', 'but', 'or', 'nor', 'not', 'so', 'yet', 'both', 'either',
    'if', 'then', 'than', 'as', 'is', 'am', 'are', 'was', 'were', 'be',
    'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
    'would', 'could', 'should', 'may', 'might', 'shall', 'can', 'need',
    'dare', 'ought', 'used', 'just', 'also', 'very', 'really',

    // 动词（高频）
    'go', 'goes', 'going', 'gone', 'went', 'get', 'gets', 'got', 'gotten',
    'getting', 'make', 'makes', 'made', 'making', 'know', 'knows', 'knew',
    'known', 'think', 'thinks', 'thought', 'take', 'takes', 'took', 'taken',
    'see', 'sees', 'saw', 'seen', 'come', 'comes', 'came', 'want', 'wants',
    'wanted', 'look', 'looks', 'looked', 'looking', 'give', 'gives', 'gave',
    'given', 'tell', 'tells', 'told', 'find', 'finds', 'found', 'say',
    'says', 'said', 'let', 'put', 'keep', 'keeps', 'kept', 'begin',
    'begins', 'began', 'begun', 'seem', 'seems', 'seemed', 'help', 'helps',
    'helped', 'show', 'shows', 'showed', 'shown', 'hear', 'hears', 'heard',
    'play', 'plays', 'played', 'playing', 'run', 'runs', 'ran', 'running',
    'move', 'moves', 'moved', 'moving', 'live', 'lives', 'lived', 'living',
    'believe', 'believes', 'believed', 'bring', 'brings', 'brought',
    'happen', 'happens', 'happened', 'must', 'provide', 'provides',
    'sit', 'sits', 'sat', 'sitting', 'stand', 'stands', 'stood', 'standing',
    'lose', 'loses', 'lost', 'pay', 'pays', 'paid', 'meet', 'meets',
    'met', 'include', 'includes', 'included', 'continue', 'continues',
    'set', 'sets', 'learn', 'learns', 'learned', 'learning', 'change',
    'changes', 'changed', 'changing', 'lead', 'leads', 'led', 'understand',
    'understands', 'understood', 'watch', 'watches', 'watched', 'watching',
    'follow', 'follows', 'followed', 'following', 'stop', 'stops',
    'stopped', 'stopping', 'create', 'creates', 'created', 'creating',
    'speak', 'speaks', 'spoke', 'spoken', 'read', 'reads', 'reading',
    'allow', 'allows', 'allowed', 'add', 'adds', 'added', 'adding',
    'spend', 'spends', 'spent', 'spending', 'win', 'wins', 'won', 'winning',
    'open', 'opens', 'opened', 'opening', 'walk', 'walks', 'walked',
    'walking', 'eat', 'eats', 'ate', 'eaten', 'eating', 'drink', 'drinks',
    'drank', 'drunk', 'drinking', 'sleep', 'sleeps', 'slept', 'sleeping',
    'wait', 'waits', 'waited', 'waiting', 'try', 'tries', 'tried', 'trying',
    'ask', 'asks', 'asked', 'asking', 'call', 'calls', 'called', 'calling',
    'feel', 'feels', 'felt', 'feeling', 'become', 'becomes', 'became',
    'leave', 'leaves', 'left', 'leaving', 'hold', 'holds', 'held', 'holding',
    'start', 'starts', 'started', 'starting', 'turn', 'turns', 'turned',
    'turning', 'write', 'writes', 'wrote', 'written', 'writing',
    'love', 'loves', 'loved', 'loving', 'buy', 'buys', 'bought', 'buying',
    'send', 'sends', 'sent', 'sending', 'build', 'builds', 'built',
    'building', 'fall', 'falls', 'fell', 'fallen', 'falling', 'cut', 'cuts',
    'cutting', 'reach', 'reaches', 'reached', 'reaching', 'kill', 'kills',
    'killed', 'killing', 'remain', 'remains', 'remained', 'suggest',
    'suggests', 'suggested', 'raise', 'raises', 'raised', 'raising',
    'pass', 'passes', 'passed', 'passing', 'sell', 'sells', 'sold',
    'selling', 'require', 'requires', 'required', 'report', 'reports',
    'reported', 'decide', 'decides', 'decided', 'deciding', 'pull', 'pulls',
    'pulled', 'pulling', 'push', 'pushes', 'pushed', 'pushing', 'carry',
    'carries', 'carried', 'carrying', 'pick', 'picks', 'picked', 'picking',
    'sing', 'sings', 'sang', 'sung', 'singing', 'dance', 'dances', 'danced',
    'dancing', 'fight', 'fights', 'fought', 'fighting', 'catch', 'catches',
    'caught', 'catching', 'throw', 'throws', 'threw', 'thrown', 'throwing',
    'draw', 'draws', 'drew', 'drawn', 'drawing', 'drop', 'drops', 'dropped',
    'dropping', 'drive', 'drives', 'drove', 'driven', 'driving', 'fly',
    'flies', 'flew', 'flown', 'flying', 'break', 'breaks', 'broke',
    'broken', 'breaking', 'teach', 'teaches', 'taught', 'teaching',
    'grow', 'grows', 'grew', 'grown', 'growing', 'hang', 'hangs', 'hung',
    'hanging', 'hide', 'hides', 'hid', 'hidden', 'hiding', 'hit', 'hits',
    'hitting', 'hurt', 'hurts', 'hurting', 'jump', 'jumps', 'jumped',
    'jumping', 'lay', 'lays', 'laid', 'lying', 'lie', 'lies', 'lied',
    'lift', 'lifts', 'lifted', 'lifting', 'ride', 'rides', 'rode', 'ridden',
    'riding', 'ring', 'rings', 'rang', 'rung', 'ringing', 'rise', 'rises',
    'rose', 'risen', 'rising', 'shake', 'shakes', 'shook', 'shaken',
    'shaking', 'shut', 'shuts', 'shutting', 'stick', 'sticks', 'stuck',
    'sticking', 'swim', 'swims', 'swam', 'swum', 'swimming', 'tear', 'tears',
    'tore', 'torn', 'tearing', 'wake', 'wakes', 'woke', 'woken', 'waking',
    'wear', 'wears', 'wore', 'worn', 'wearing', 'bite', 'bites', 'bit',
    'bitten', 'biting', 'blow', 'blows', 'blew', 'blown', 'blowing',
    'dig', 'digs', 'dug', 'digging', 'feed', 'feeds', 'fed', 'feeding',
    'forget', 'forgets', 'forgot', 'forgotten', 'forgetting', 'forgive',
    'forgives', 'forgave', 'forgiven', 'forgiving', 'lend', 'lends', 'lent',
    'lending', 'light', 'lights', 'lit', 'lighting', 'owe', 'owes', 'owed',
    'owing', 'shine', 'shines', 'shone', 'shining', 'steal', 'steals',
    'stole', 'stolen', 'stealing', 'sweep', 'sweeps', 'swept', 'sweeping',

    // 名词（高频）
    'time', 'year', 'people', 'way', 'day', 'man', 'men', 'woman', 'women',
    'child', 'children', 'world', 'life', 'hand', 'hands', 'part', 'parts',
    'place', 'places', 'case', 'cases', 'week', 'weeks', 'company',
    'system', 'systems', 'program', 'programs', 'question', 'questions',
    'work', 'works', 'government', 'number', 'numbers', 'night', 'nights',
    'point', 'points', 'home', 'homes', 'water', 'waters', 'room', 'rooms',
    'mother', 'mothers', 'area', 'areas', 'money', 'story', 'stories',
    'fact', 'facts', 'month', 'months', 'lot', 'lots', 'right', 'rights',
    'study', 'studies', 'book', 'books', 'eye', 'eyes', 'job', 'jobs',
    'word', 'words', 'business', 'issue', 'issues', 'side', 'sides',
    'kind', 'kinds', 'head', 'heads', 'house', 'houses', 'service',
    'services', 'friend', 'friends', 'father', 'fathers', 'power', 'powers',
    'hour', 'hours', 'game', 'games', 'line', 'lines', 'end', 'ends',
    'members', 'family', 'families', 'students', 'group', 'groups',
    'country', 'countries', 'problem', 'problems', 'city', 'cities',
    'community', 'communities', 'name', 'names', 'president', 'team',
    'teams', 'minute', 'minutes', 'idea', 'ideas', 'body', 'bodies',
    'information', 'back', 'backs', 'parent', 'parents', 'face', 'faces',
    'others', 'level', 'levels', 'office', 'offices', 'door', 'doors',
    'health', 'person', 'persons', 'art', 'arts', 'war', 'wars', 'history',
    'party', 'parties', 'result', 'results', 'change', 'changes', 'morning',
    'mornings', 'reason', 'reasons', 'research', 'girl', 'girls', 'guy',
    'guys', 'moment', 'moments', 'air', 'teacher', 'teachers', 'force',
    'forces', 'education', 'food', 'foods', 'color', 'colors', 'car', 'cars',
    'dog', 'dogs', 'cat', 'cats', 'music', 'songs', 'song', 'school',
    'schools', 'student', 'class', 'classes', 'table', 'tables', 'chair',
    'chairs', 'phone', 'phones', 'picture', 'pictures', 'wall', 'walls',
    'window', 'windows', 'bed', 'beds', 'tree', 'trees', 'sun', 'moon',
    'star', 'stars', 'sky', 'rain', 'snow', 'wind', 'fire', 'fires',
    'road', 'roads', 'street', 'streets', 'river', 'rivers', 'sea', 'ocean',
    'mountain', 'mountains', 'island', 'islands', 'king', 'kings', 'queen',
    'queens', 'heart', 'hearts', 'love', 'loves', 'hope', 'hopes', 'dream',
    'dreams', 'fear', 'fears', 'death', 'deaths', 'blood', 'brother',
    'brothers', 'sister', 'sisters', 'son', 'sons', 'daughter', 'daughters',
    'husband', 'husbands', 'wife', 'wives', 'baby', 'babies', 'boy', 'boys',
    'girl', 'girls', 'ship', 'ships', 'boat', 'boats', 'plane', 'planes',
    'train', 'trains', 'bus', 'buses', 'box', 'boxes', 'bag', 'bags',
    'ball', 'balls', 'cup', 'cups', 'glass', 'glasses', 'key', 'keys',
    'map', 'maps', 'letter', 'letters', 'page', 'pages', 'news', 'paper',
    'papers', 'film', 'films', 'movie', 'movies', 'video', 'videos',
    'photo', 'photos', 'camera', 'cameras', 'computer', 'computers',
    'chip', 'chips', 'test', 'tests', 'score', 'scores', 'chip', 'chips',

    // 形容词/副词
    'good', 'new', 'first', 'last', 'long', 'great', 'little', 'own',
    'other', 'old', 'young', 'different', 'big', 'small', 'large', 'next',
    'early', 'important', 'few', 'public', 'bad', 'same', 'able', 'free',
    'sure', 'true', 'real', 'full', 'special', 'easy', 'clear', 'recent',
    'certain', 'personal', 'open', 'red', 'blue', 'green', 'white',
    'black', 'dark', 'bright', 'light', 'heavy', 'fast', 'slow', 'hot',
    'cold', 'warm', 'cool', 'hard', 'soft', 'strong', 'weak', 'rich',
    'poor', 'happy', 'sad', 'angry', 'afraid', 'alone', 'safe', 'sorry',
    'whole', 'quite', 'rather', 'pretty', 'enough', 'too', 'also',
    'well', 'still', 'already', 'even', 'never', 'always', 'often',
    'sometimes', 'usually', 'here', 'there', 'now', 'again', 'once',
    'every', 'each', 'many', 'much', 'some', 'any', 'all', 'more', 'most',
    'less', 'least', 'fewer', 'fewest', 'better', 'best', 'worse', 'worst',
    'only', 'just', 'almost', 'already', 'away', 'back', 'far', 'close',
    'high', 'low', 'deep', 'shallow', 'wide', 'narrow', 'thick', 'thin',

    // 其他常用
    'yes', 'no', 'ok', 'okay', 'please', 'thanks', 'thank', 'sorry',
    'hello', 'hi', 'bye', 'goodbye', 'oh', 'ah', 'wow', 'hey',
    'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'hundred', 'thousand', 'million', 'billion',
    'first', 'second', 'third', 'half', 'quarter',
  };
}
