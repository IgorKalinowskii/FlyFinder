import 'package:http/http.dart' as http;
import 'dart:convert';

class AmadeusApi {
  final String apiKey = 'Hq6UyTRsPAOVz4GfURbCUAgxWVSh75ZD';
  final String apiSecret = 'ZjgrDbUvTuUhoh3s';
  final String tokenUrl = 'https://test.api.amadeus.com/v1/security/oauth2/token';
  final String apiUrl = 'https://test.api.amadeus.com/v2/shopping/flight-offers';

  Future<String> getAccessToken() async {
    final response = await http.post(
      Uri.parse(tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': apiKey,
        'client_secret': apiSecret,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['access_token'];
    } else {
      throw Exception('Failed to retrieve access token');
    }
  }

  Future<List<dynamic>> searchFlights(
      String origin,
      String destination,
      String departureDate,
      String returnDate,
      String numberOfPassengers // Dodajemy nowy argument
      ) async {
    final accessToken = await getAccessToken();
    final response = await http.get(
      Uri.parse(apiUrl).replace(queryParameters: {
        'originLocationCode': origin,
        'destinationLocationCode': destination,
        'departureDate': departureDate,
        'returnDate': returnDate,
        'adults': numberOfPassengers, // Dodajemy liczbę pasażerów do parametrów zapytania
        'nonStop': 'false',
        'max': '10',
      }),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/vnd.amadeus+json',
      },
    );

    if (response.statusCode == 200) {
      return removeDuplicates(json.decode(response.body)['data']);
    } else {
      print('Failed to search flights: ${response.body}');
      throw Exception('Failed to search flights');
    }
  }

  List<Map<String, dynamic>> removeDuplicates(List<dynamic> rawFlights) {
    Set<String> flightNumbers = Set();
    List<Map<String, dynamic>> uniqueFlights = [];

    for (var flight in rawFlights) {
      if (flight is! Map<String, dynamic>) {
        throw Exception('Invalid type: ${flight.runtimeType}');
      }

      String flightNumber = flight['itineraries'][0]['segments'][0]['carrierCode'] +
          flight['itineraries'][0]['segments'][0]['number'];
      if (!flightNumbers.contains(flightNumber)) {
        flightNumbers.add(flightNumber);
        uniqueFlights.add(flight);
      }
    }

    return uniqueFlights;
  }
}

