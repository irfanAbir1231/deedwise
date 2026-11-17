import 'package:flutter/services.dart';

class DeedModeration {
  static const profanityMessage =
      'অশ্লীল বা অপমানজনক ভাষা ব্যবহার করা যাবে না। লেখাটি সংশোধন করুন।';
  static const harmMessage =
      'ক্ষতিকর বা অপরাধমূলক কাজ good deed হিসেবে সংরক্ষণ করা যাবে না।';
  static final Set<String> _words = {
    'fuck',
    'fucking',
    'fucked',
    'motherfucker',
    'shit',
    'bullshit',
    'bitch',
    'asshole',
    'cunt',
    'চোদা',
    'মাগী',
    'গান্ডু',
    'মাদার চোদ',
    'খানকি',
    'খানকির',
    'বোকাচোদা',
    'চুদা',
    'choda',
    'chudi',
    'khanki',
    'madarchod',
    'bokachoda',
    'gandu',
  };
  static Future<void>? _loading;
  static bool _loaded = false;
  static Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    final text = await rootBundle.loadString('assets/moderation/blocked.txt');
    _words.addAll(text.split('\n').map(normalize).where((w) => w.isNotEmpty));
    _loaded = true;
  }

  static String normalize(String text) {
    var value = text.toLowerCase().replaceAll(
      RegExp(r'[\u200B-\u200F\uFEFF]'),
      '',
    );
    const substitutions = {
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      '@': 'a',
      r'$': 's',
    };
    substitutions.forEach((a, b) => value = value.replaceAll(a, b));
    return value
        .replaceAll(RegExp(r'[^a-z\u0980-\u09FF]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? check(String text) {
    final normalized = normalize(text);
    for (final word in _words) {
      if (' $normalized '.contains(' $word ')) return profanityMessage;
    }
    // Catch separated letters without substring matching inside innocent words.
    final separated = text.toLowerCase().replaceAll(
      RegExp(r'[\u200B-\u200F\uFEFF]'),
      '',
    );
    for (final word in _words.where(
      (w) => RegExp(r'^[a-z]{4,}$').hasMatch(w),
    )) {
      final pattern = word.split('').map(RegExp.escape).join(r'[\s.*_\-]+');
      if (RegExp('(^|[^a-z])$pattern(\$|[^a-z])').hasMatch(separated)) {
        return profanityMessage;
      }
    }
    // Avoid classifying every use of "kill" as wrongdoing (e.g. prevention).
    // An affirmed harmful clause is blocked even if another clause is positive.
    for (final clause in normalized.split(
      RegExp(r'\b(?:but|however|although)\b|কিন্তু'),
    )) {
      final prevented = RegExp(
        r'\b(?:prevented|stopped|refused|avoided|refrain|refrained|did not|didnt|never)\b|থামিয়েছি|বিরত|করিনি|ঠেকিয়েছি|বাঁচিয়েছি|বাঁচাতে',
      ).hasMatch(clause);
      if (!prevented &&
          RegExp(
            r'\b(?:kill(?:ed|ing)?|murder(?:ed|ing)?|rape(?:d)?|raping|stab(?:bed|bing)?|rob(?:bed|bing)?|steal|stole|tortur(?:e|ed|ing))\b|খুন|হত্যা করেছি|হত্যা করতে|ধর্ষণ করেছি|চুরি করেছি|খুন করতে|mere fel|khun kor|hotta kor|churi kor',
          ).hasMatch(clause)) {
        return harmMessage;
      }
    }
    return null;
  }

  static bool needsContextCheck(String text) => RegExp(
    r'\b(kill|killed|killing|murder|hurt|harm|attack|weapon|poison|steal|stole|rob|rape|fraud|scam|abuse)\b|হত্যা|খুন|চুরি|ধর্ষণ|ক্ষতি|মেরে|খারাপ|mere|khun|hotta|churi',
  ).hasMatch(normalize(text));
}
