import 'package:flutter/material.dart';
import 'app/app_features.dart';
import 'theme/app_theme.dart';

void main() {
  const features = AppFeatures.webReadonly();
  runApp(const WebPlaceholderApp(features: features));
}

class WebPlaceholderApp extends StatelessWidget {
  final AppFeatures features;

  const WebPlaceholderApp({super.key, required this.features});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pelada Manager',
      theme: AppTheme.dark,
      home: const Scaffold(
        body: Center(
          child: Text(
            'Site em construção',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
