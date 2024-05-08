// Main
import 'package:flutter/material.dart';
import 'package:odp/pages/home_page.dart'; // Import your pages
import 'package:fluttertoast/fluttertoast.dart';
import 'package:odp/pages/login.dart';

void main() {
  runApp(MyApp());
}

// MyApp class
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ODx App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginApp(), // Set your initial page
    );
  }
}
