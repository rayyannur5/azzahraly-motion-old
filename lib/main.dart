import 'dart:io';

import 'package:azzahraly_motion/home.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  if (Platform.isWindows) {
    WindowManager.instance.setMinimumSize(const Size(1280, 720));
    // WindowManager.instance.setMaximumSize(const Size(1280, 720));
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorSchemeSeed: Colors.cyan,
        // filledButtonTheme: FilledButtonThemeData(
        //   style: ButtonStyle(
        //     backgroundColor: MaterialStatePropertyAll(Colors.amber.shade800),
        //   ),
        // ),
        // iconButtonTheme: IconButtonThemeData(
        //     style: ButtonStyle(
        //   backgroundColor: MaterialStatePropertyAll(Colors.amber.shade800),
        // )),
      ),
      home: Home(),
    );
  }
}
