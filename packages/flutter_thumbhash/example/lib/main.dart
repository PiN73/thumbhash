import 'package:flutter/material.dart';
import 'package:flutter_thumbhash/flutter_thumbhash.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
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
