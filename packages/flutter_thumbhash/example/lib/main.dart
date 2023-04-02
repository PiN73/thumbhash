import 'package:flutter/material.dart';
import 'package:flutter_thumbhash/flutter_thumbhash.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
    return Scaffold(
      backgroundColor: hash.toAverageColor(),
      body: Image(
        image: hash.toImage(),
        height: double.infinity,
        width: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }
}
