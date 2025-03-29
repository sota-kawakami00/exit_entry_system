import 'package:ai_barcode/ai_barcode.dart';
import 'package:exit_entry_system/firebase_options.dart';
import 'package:exit_entry_system/screen/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web用のプラグイン初期化
  setUrlStrategy(PathUrlStrategy());

  // 日本語ロケールの初期化
  await initializeDateFormatting('ja_JP', null);

  // Firebase初期化（DefaultFirebaseOptionsがない場合の代替方法）
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

// Webアプリケーション設定
void configureApp() {
  // カメラ許可ダイアログを表示させるためのフラグ
  // Webプラットフォームのみで実行
  if (const bool.fromEnvironment('dart.library.js_util')) {
    // プラグインは自動登録されるべきなので、明示的な登録は不要
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '入退室管理システム',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}