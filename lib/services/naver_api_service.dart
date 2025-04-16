import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geocoding/geocoding.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NaverApiService {
  // 상수 값 대신 dotenv에서 가져오도록 수정
  String get clientId => dotenv.env['NAVER_CLIENT_ID'] ?? '';
  String get clientSecret => dotenv.env['NAVER_CLIENT_SECRET'] ?? '';
  // VWORLD API 키
  static const String vworldApiKey = 'B3EFCFAA-875F-3E0B-A89C-760CFB5CA831';
  
  final logger = Logger();

  // 위치 기반 검색: 현재 위치의 동네 이름을 반환
  Future<String> getCurrentLocationName() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw '위치 서비스가 비활성화되어 있습니다.';

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) throw '위치 권한이 거부되었습니다.';
    }

    final position = await geo.Geolocator.getCurrentPosition();
    logger.i('현재 위치: 위도 ${position.latitude}, 경도 ${position.longitude}');

    // VWORLD API를 통해 주소 가져오기
    final address = await getAddressFromVWorld(position.latitude, position.longitude);
    
    logger.i('VWORLD API 응답 주소: $address');
    return address;
  }

  // VWORLD API를 통해 좌표값으로 주소 가져오기
  Future<String> getAddressFromVWorld(double latitude, double longitude) async {
    final url = Uri.parse(
      'http://api.vworld.kr/req/address?service=address&request=getAddress&version=2.0&crs=epsg:4326&point=$longitude,$latitude&format=json&type=both&key=$vworldApiKey'
    );

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('VWORLD API 응답: $data');
        
        if (data['response']['status'] == 'OK') {
          final result = data['response']['result'];
          if (result.isNotEmpty) {
            // 지번 주소와 도로명 주소 중 선택
            final structure = result[0]['structure'];
            
            // 동까지만 표시 (시/군/구/동)
            String address = '';
            if (structure.containsKey('level1') && structure['level1'] != null) {
              address += structure['level1'];
            }
            if (structure.containsKey('level2') && structure['level2'] != null) {
              address += ' ${structure['level2']}';
            }
            if (structure.containsKey('level4') && structure['level4'] != null && structure['level4'].toString().isNotEmpty) {
              address += ' ${structure['level4']}';
            } else if (structure.containsKey('level5') && structure['level5'] != null && structure['level5'].toString().isNotEmpty) {
              address += ' ${structure['level5']}';
            }
            
            return address.trim();
          }
        }
        throw '주소를 찾을 수 없습니다.';
      } else {
        logger.e('VWORLD API 오류: ${response.statusCode}');
        logger.e('VWORLD API 응답: ${response.body}');
        throw 'VWORLD API 응답 오류: ${response.statusCode}';
      }
    } catch (e) {
      logger.e('VWORLD API 호출 오류: $e');
      
      // VWORLD API 실패 시 기존 방식으로 대체
      try {
        final placemarks = await placemarkFromCoordinates(
          latitude,
          longitude,
          localeIdentifier: 'ko_KR',
        );
        if (placemarks.isEmpty) throw '주소 정보를 가져올 수 없습니다.';

        final placemark = placemarks.first;
        final locationName = placemark.locality ?? placemark.subLocality ?? '알 수 없는 지역';
        logger.i('Geocoding API 응답 주소: $locationName');
        return locationName;
      } catch (geocodingError) {
        logger.e('Geocoding API 호출 오류: $geocodingError');
        throw '위치 정보를 주소로 변환할 수 없습니다.';
      }
    }
  }

  // 일반 검색: 검색어만으로 네이버 API 호출
  Future<List<Map<String, dynamic>>> searchLocal(String query) async {
    logger.i('검색어: $query');
    
    // 수정된 부분: 직접 URL을 만들지 않고 query parameters로 제공
    final url = Uri.parse('https://openapi.naver.com/v1/search/local.json');
    
    final queryParams = {
      'query': query,
      'display': '5', // 최대 5개 결과 반환
      'start': '1',
      'sort': 'random',
    };
    
    final finalUrl = Uri(
      scheme: url.scheme,
      host: url.host,
      path: url.path,
      queryParameters: queryParams,
    );

    logger.i('요청 URL: $finalUrl');
    logger.i('사용된 Client ID: $clientId');
    logger.i('사용된 Client Secret: ${clientSecret.substring(0, 3)}...'); // 보안을 위해 일부만 출력

    final response = await http.get(
      finalUrl,
      headers: {
        'X-Naver-Client-Id': clientId,
        'X-Naver-Client-Secret': clientSecret,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      logger.i('API 응답 데이터: $data');
      if (data['items'] == null || data['items'].isEmpty) {
        logger.w('검색 결과가 없습니다. items 필드가 비어있습니다.');
        return [];
      }
      return List<Map<String, dynamic>>.from(data['items']);
    } else {
      logger.w('응답 코드: ${response.statusCode}');
      logger.w('응답 메시지: ${response.body}');
      throw Exception('Failed to load data from Naver API: ${response.statusCode}');
    }
  }
}