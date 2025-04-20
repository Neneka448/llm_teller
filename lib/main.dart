import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 导入 Riverpod
import 'screens/chat_screen.dart'; // 引入聊天屏幕

void main() {
  // Wrap the entire app in a ProviderScope
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat UI',
      theme: ThemeData(
        primarySwatch: Colors.blue, // 主题颜色
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // 可以根据需要进一步定制主题
         appBarTheme: AppBarTheme(
            backgroundColor: Colors.white, // 默认 AppBar 背景色
            foregroundColor: Colors.black87, // 默认 AppBar 前景色
            iconTheme: IconThemeData(color: Colors.grey.shade600), // 统一设置 AppBar 图标颜色
         ),
         // 设置卡片颜色，影响输入框背景
         cardColor: Colors.white,
          // 设置背景色
         scaffoldBackgroundColor: Colors.grey.shade100,
      ),
      home: const ChatScreen(), // 将 ChatScreen 设置为主屏幕
      debugShowCheckedModeBanner: false, // 移除右上角的 Debug 标签
    );
  }
}
