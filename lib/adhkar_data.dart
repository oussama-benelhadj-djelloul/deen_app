import 'dart:convert';
import 'package:flutter/services.dart';

// Hisn al-Muslim (حصن المسلم) by Sa'id bin Ali bin Wahf al-Qahtani, taken
// from the official API at hisnmuslim.com and bundled in
// assets/data/hisn_almuslim.json so it works fully offline.

class Dhikr {
  final int id;
  final String text;
  // How many times it should be said
  final int repeat;

  const Dhikr({required this.id, required this.text, required this.repeat});

  factory Dhikr.fromJson(Map<String, dynamic> json) => Dhikr(
    id: json['id'] as int,
    text: json['text'] as String,
    repeat: json['repeat'] as int,
  );
}

class DhikrChapter {
  final int id;
  final String title;
  final List<Dhikr> adhkar;

  const DhikrChapter({
    required this.id,
    required this.title,
    required this.adhkar,
  });

  factory DhikrChapter.fromJson(Map<String, dynamic> json) => DhikrChapter(
    id: json['id'] as int,
    title: json['title'] as String,
    adhkar: [for (final d in json['adhkar'] as List) Dhikr.fromJson(d)],
  );
}

class HisnAlMuslim {
  static Future<List<DhikrChapter>>? _chapters;

  // Loaded once from the bundled asset, then cached for the app's lifetime
  static Future<List<DhikrChapter>> chapters() => _chapters ??= _load();

  static Future<DhikrChapter?> chapter(int id) async {
    for (final c in await chapters()) {
      if (c.id == id) return c;
    }
    return null;
  }

  static Future<List<DhikrChapter>> _load() async {
    final raw = await rootBundle.loadString('assets/data/hisn_almuslim.json');
    return [for (final c in jsonDecode(raw) as List) DhikrChapter.fromJson(c)];
  }
}

// Themed groups shown on the Adhkar tab. Each one lists Hisn al-Muslim
// chapter ids in reading order.
const adhkarCoverImage = 'assets/images/adhkar_cover.png';

class AdhkarCategory {
  final String title;
  // Short name written in white on the card cover
  final String coverLabel;
  // Asset path of the cover painting
  final String image;
  final List<int> chapterIds;

  const AdhkarCategory({
    required this.title,
    required this.coverLabel,
    required this.chapterIds,
    this.image = adhkarCoverImage,
  });
}

const adhkarCategories = [
  AdhkarCategory(
    title: 'أذكار الليل والنهار',
    coverLabel: 'الليل',
    chapterIds: [27, 28, 1, 29, 30, 31],
  ),
  AdhkarCategory(
    title: 'أذكار الصلاة',
    coverLabel: 'الصلاة',
    chapterIds: [
      15, 12, 13, 14, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 32, 33, //
    ],
  ),
  AdhkarCategory(
    title: 'أذكار البيت والطهارة',
    coverLabel: 'البيت',
    chapterIds: [10, 11, 6, 7, 8, 9, 2, 3, 4, 5],
  ),
  AdhkarCategory(
    title: 'أذكار الطعام والصيام',
    coverLabel: 'الطعام',
    chapterIds: [69, 70, 71, 72, 73, 68, 74, 75, 76, 67],
  ),
  AdhkarCategory(
    title: 'أذكار السفر',
    coverLabel: 'السفر',
    chapterIds: [95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105],
  ),
  AdhkarCategory(
    title: 'أدعية الهم والكرب',
    coverLabel: 'الكرب',
    chapterIds: [
      34, 35, 43, 46, 41, 36, 37, 38, 39, 40, 42, 45, 128, 44, 82, 92, //
      94, 88, 124, 125, 126,
    ],
  ),
  AdhkarCategory(
    title: 'أذكار المرض والعزاء',
    coverLabel: 'المرض',
    chapterIds: [49, 50, 51, 83, 52, 53, 54, 55, 56, 57, 58, 59, 60],
  ),
  AdhkarCategory(
    title: 'أذكار المطر والريح',
    coverLabel: 'المطر',
    chapterIds: [61, 62, 63, 64, 65, 66],
  ),
  AdhkarCategory(
    title: 'أذكار الحج والعمرة',
    coverLabel: 'الحج',
    chapterIds: [115, 116, 117, 118, 119, 120, 121],
  ),
  AdhkarCategory(
    title: 'التسبيح والاستغفار',
    coverLabel: 'التسبيح',
    chapterIds: [130, 131, 129, 107],
  ),
  AdhkarCategory(
    title: 'الآداب والمعاملات',
    coverLabel: 'الآداب',
    chapterIds: [
      108, 109, 77, 78, 84, 85, 86, 87, 89, 90, 91, 93, 112, 113, 114, //
      79, 80, 81, 47, 48, 106, 122, 123, 127, 110, 111, 132,
    ],
  ),
];

// "N أذكار" with correct Arabic number agreement
String adhkarCountLabel(int n) => switch (n) {
  1 => 'ذكر واحد',
  2 => 'ذكران',
  >= 3 && <= 10 => '$n أذكار',
  _ => '$n ذكرًا',
};

// "N مرات" with correct Arabic number agreement
String repeatLabel(int n) => switch (n) {
  1 => 'مرة واحدة',
  2 => 'مرتان',
  >= 3 && <= 10 => '$n مرات',
  _ => '$n مرة',
};
