import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import '../screens/home_page.dart';

final logger = Logger();

Future<void> main() async {
  // Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // .env 파일 로드
    await dotenv.load(fileName: "assets/.env");
    logger.i("dotenv 로드 성공!");
  } catch (e) {
    logger.e("dotenv 로드 오류: $e");
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Material 3 디자인 사용
      ),
      home: const HomePage(),
    );
  }
}