import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_state.dart';
import 'views/main/main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 窗口管理器初始化
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    title: 'ACode',
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 初始化应用状态
  final appState = AppState();
  await appState.initialize();

  runApp(ACodeApp(appState: appState));
}

class ACodeApp extends StatelessWidget {
  final AppState appState;

  const ACodeApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'ACode',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF007AFF),
          fontFamily: 'Segoe UI',
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF007AFF),
          fontFamily: 'Segoe UI',
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        ),
        home: const Scaffold(body: MainView()),
      ),
    );
  }
}
