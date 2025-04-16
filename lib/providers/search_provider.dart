import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchResult {
  final String title;
  final String link;
  final String category;
  final String description;
  final String address;
  final String roadAddress;
  final int mapx;
  final int mapy;

  SearchResult({
    required this.title,
    required this.link,
    required this.category,
    required this.description,
    required this.address,
    required this.roadAddress,
    required this.mapx,
    required this.mapy,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title']?.replaceAll(RegExp(r'<[^>]+>'), '') ?? '',
      link: json['link'] ?? 'https://www.naver.com',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      roadAddress: json['roadAddress'] ?? '',
      mapx: int.tryParse(json['mapx'].toString()) ?? 0,
      mapy: int.tryParse(json['mapy'].toString()) ?? 0,
    );
  }
}

final searchResultsProvider = StateProvider<List<SearchResult>>((ref) => []);
final searchQueryProvider = StateProvider<String>((ref) => '');