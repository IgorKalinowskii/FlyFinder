import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FlightCard extends StatelessWidget {
  final Map<String, dynamic> flight;

  FlightCard({required this.flight});

  String formatTime(String isoDateTime) {
    DateTime dateTime = DateTime.parse(isoDateTime).toLocal();
    return DateFormat('HH:mm').format(dateTime);
  }

  String formatDuration(String isoDuration) {
    String hours = '';
    String minutes = '';
    RegExp regExp = RegExp(r'PT(\d+H)?(\d+M)?');
    Match? match = regExp.firstMatch(isoDuration);
    if (match != null) {
      hours = match.group(1)?.replaceAll('H', 'h') ?? '';
      minutes = match.group(2)?.replaceAll('M', 'm') ?? '';
    }
    return '$hours $minutes'.trim();
  }

  @override
  Widget build(BuildContext context) {
    // Rozważamy tylko pierwszą część itinerera, aby ustalić czy jest przesiadka
    var itinerary = flight['itineraries'][0];
    var departureSegment = itinerary['segments'][0]['departure'];
    var arrivalSegment = itinerary['segments'].last['arrival'];
    var duration = formatDuration(itinerary['duration']);
    var flightNumber = itinerary['segments'][0]['carrierCode'] + itinerary['segments'][0]['number'];

    String flightType = 'Lot z przesiadką'; // domyślnie ustawiamy jako lot z przesiadką
    // Sprawdzamy, czy istnieje tylko jeden segment w itinererze, co oznacza lot bezpośredni
    if (itinerary['segments'].length == 1) {
      flightType = 'Lot bez przesiadki'; // jeśli jest tylko jeden segment, to jest to lot bezpośredni
    }

    return Card(
      margin: EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('${departureSegment['iataCode']} - wylot'),
                Text(flightType),
                Text('${arrivalSegment['iataCode']} - przylot'),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(formatTime(departureSegment['at'])),
                Icon(Icons.airplanemode_active),
                Text(formatTime(arrivalSegment['at'])),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Numer lotu: $flightNumber'),
              ],
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.flight_takeoff),
                    Expanded(
                      child: Divider(
                        color: Colors.black,
                        height: 20,
                        thickness: 1.5,
                      ),
                    ),
                    Icon(Icons.flight_land),
                  ],
                ),
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Text(duration, style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}




