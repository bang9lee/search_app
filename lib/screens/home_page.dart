import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/naver_api_service.dart';
import '../providers/search_provider.dart';
import 'web_view_page.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final NaverApiService _naverApiService = NaverApiService();
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    // 검색 결과 상태 가져오기
    final searchResults = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('장소 검색'),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed, color: Colors.blue, size: 24.0),
            onPressed: _isSearching ? null : () {
              // 현재 위치 기반 검색 실행
              _getCurrentLocation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search, // 검색 버튼으로 설정
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: '검색어 입력 (예: 강남역, 홍대 카페)',
                border: OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blue, size: 24.0),
                  onPressed: () async {
                    final query = _controller.text;
                    if (query.isNotEmpty) {
                      await _search(query);
                    }
                  },
                ),
              ),
              onSubmitted: (query) async {
                // 엔터 키 눌렀을 때 검색 실행
                if (query.isNotEmpty) {
                  await _search(query);
                }
              },
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.grey[100], // 배경색을 연한 회색으로 설정
              child: _isSearching 
                  ? const Center(child: CircularProgressIndicator())
                  : searchResults.isEmpty
                      ? const Center(child: Text('검색 결과가 없습니다.\n우측 상단의 위치 아이콘을 눌러 현재 위치 검색을 시도해보세요.', textAlign: TextAlign.center))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final result = searchResults[index];
                            return Column(
                              children: [
                                Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 2,
                                  color: Colors.white, // 카드 색상을 흰색으로 설정
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    title: Text(
                                      result.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(' ${result.category}'),
                                        const SizedBox(height: 4),
                                        Text(' ${result.roadAddress}'),
                                      ],
                                    ),
                                    onTap: () {
                                      // 검색 결과 터치 시 웹뷰로 이동
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => WebViewPage(url: result.link),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12), // 각 카드 사이에 간격 추가
                              ],
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // 위치 가져오기 메서드
  Future<void> _getCurrentLocation() async {
    // 이미 검색 중이면 중단
    if (_isSearching) return;
    
    // 검색 상태 설정
    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }
    
    try {
      // 현재 위치 기반 검색 (VWORLD API 사용)
      final locationName = await _naverApiService.getCurrentLocationName();
      
      // 컴포넌트가 여전히 마운트되어 있는지 확인
      if (!mounted) return;
      
      // 검색어 설정 및 검색 실행
      _controller.text = locationName;
      await _search(locationName);
    } catch (e) {
      // 컴포넌트가 여전히 마운트되어 있는지 확인
      if (!mounted) return;
      
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 기반 검색 오류: $e')),
      );
    }
    
    // 검색 상태 초기화 (finally 없이 마지막에 실행)
    if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // 검색 기능 실행 메서드
  Future<void> _search(String query) async {
    // 이미 검색 중이면 중단
    if (_isSearching) return;
    
    // 검색 상태 설정
    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }
    
    try {
      // 검색어 상태 업데이트
      ref.read(searchQueryProvider.notifier).state = query;
      
      // API 호출로 검색 결과 가져오기
      final results = await _naverApiService.searchLocal(query);
      
      // 컴포넌트가 여전히 마운트되어 있는지 확인
      if (!mounted) return;
      
      // 검색 결과 상태 업데이트
      ref.read(searchResultsProvider.notifier).state = results
          .map((json) => SearchResult.fromJson(json))
          .toList();
      
      // 검색 결과가 없을 때 메시지 표시
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 결과가 없습니다. 다른 검색어를 시도해보세요.')),
        );
      }
    } catch (e) {
      // 컴포넌트가 여전히 마운트되어 있는지 확인
      if (!mounted) return;
      
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 중 오류: $e')),
      );
    }
    
    // 검색 상태 초기화 (finally 없이 마지막에 실행)
    if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }
  }
}