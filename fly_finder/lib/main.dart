import 'package:flutter/material.dart';
import 'flight_search_page.dart';


void main() {
  runApp( MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amadeus Flight Search',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FlightSearchPage(),
    );
  }
}
