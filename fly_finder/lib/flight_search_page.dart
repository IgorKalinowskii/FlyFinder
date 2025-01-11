import 'amadeus_api.dart';
import 'package:flutter/material.dart';
import 'flight_card.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/cupertino.dart';

class FlightSearchPage extends StatefulWidget {
  @override
  _FlightSearchPageState createState() => _FlightSearchPageState();
}

class _FlightSearchPageState extends State<FlightSearchPage> {
  final TextEditingController departureController = TextEditingController();
  final TextEditingController arrivalController = TextEditingController();
  final TextEditingController departureDateController = TextEditingController();
  final TextEditingController returnDateController = TextEditingController();
  final TextEditingController passengerCountController = TextEditingController(
      text: '1');

  String classOfService = 'Economy';

  List<Map<String, dynamic>> directFlights = [];
  List<Map<String, dynamic>> connectingFlights = [];

  List<dynamic> departureSuggestions = [];
  List<dynamic> arrivalSuggestions = [];

  List<dynamic> searchResults = [];

  final AmadeusApi amadeusApi = AmadeusApi();

  Timer? _debounce;

  bool _isLoading = false; // zmienna stanu do kontrolowania wyświetlania animacji


  @override
  void initState() {
    super.initState();
    departureDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    returnDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 7)));
  }

  @override
  void dispose() {
    // Pamiętaj, aby anulować timer, gdy widget jest usuwany
    _debounce?.cancel();
    super.dispose();
  }

  bool isInputValid() {
    // Upewnij się, że wszystkie pola zostały wypełnione
    return departureController.text.isNotEmpty &&
        arrivalController.text.isNotEmpty &&
        departureDateController.text.isNotEmpty &&
        returnDateController.text.isNotEmpty &&
        passengerCountController.text.isNotEmpty &&
        int.tryParse(passengerCountController.text) != null;
  }


  void onSearchChanged(String query, bool isDeparture) {
    // Anuluj poprzedni timer, jeśli był aktywny
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Ustaw nowy timer
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Ta funkcja zostanie wywołana po upływie czasu opóźnienia
      // jeśli użytkownik przestanie wpisywać tekst
      fetchSuggestions(query, isDeparture);
    });
  }

  void performSearch() async {
    // Ustawienie stanu na "ładowanie" przed rozpoczęciem procesu wyszukiwania
    setState(() {
      _isLoading = true;
    });

    if (!isInputValid()) {
      // Wyświetlenie dialogu, jeśli wejście jest nieprawidłowe
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text('Invalid Input'),
            content: Text('Please make sure all fields are filled correctly.'),
            actions: <Widget>[
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
      // Zakończenie ładowania jeśli dane są nieprawidłowe
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final List<dynamic> flights = await amadeusApi.searchFlights(
        departureController.text,
        arrivalController.text,
        departureDateController.text,
        returnDateController.text,
        passengerCountController.text,
      );

      // Odseparowanie lotów bezpośrednich od lotów z przesiadkami
      final separatedFlights = separateFlights(flights as List<Map<String, dynamic>>);
      setState(() {
        directFlights = separatedFlights['direct'] ?? [];
        connectingFlights = separatedFlights['connecting'] ?? [];
        _isLoading = false; // Wyłączenie stanu ładowania po uzyskaniu danych
      });
    } catch (e) {
      print('Error searching for flights: $e');
      setState(() {
        directFlights = [];
        connectingFlights = [];
        _isLoading = false; // Wyłączenie stanu ładowania również w przypadku błędu
      });
    }
  }


  void handleSearchResults(List<Map<String, dynamic>> flights) {
    final separatedFlights = separateFlights(flights);
    setState(() {
      directFlights = separatedFlights['direct']!;
      connectingFlights = separatedFlights['connecting']!;
    });
  }

  Map<String, List<Map<String, dynamic>>> separateFlights(List<Map<String, dynamic>> flights) {
    final List<Map<String, dynamic>> directFlights = [];
    final List<Map<String, dynamic>> connectingFlights = [];

    for (var flight in flights) {
      if (flight.containsKey('itineraries') && flight['itineraries'].isNotEmpty) {
        final itineraries = flight['itineraries'] as List<dynamic>;
        // Lot bezpośredni, jeśli jest tylko jeden segment
        if (itineraries[0]['segments'].length == 1) {
          directFlights.add(flight);
        } else {
          // Lot z przesiadkami, jeśli jest więcej niż jeden segment
          connectingFlights.add(flight);
        }
      }
    }
    return {'direct': directFlights, 'connecting': connectingFlights};
  }

  void _showPassengerPicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 216,
          padding: const EdgeInsets.only(top: 6.0),
          color: CupertinoColors.white,
          child: CupertinoPicker(
            itemExtent: 32.0,
            onSelectedItemChanged: (int index) {
              // Aktualizuj wartość w kontrolerze passengerCountController na wybraną wartość + 1 (ponieważ index zaczyna się od 0)
              setState(() {
                passengerCountController.text = (index + 1).toString();
              });
            },
            children: List<Widget>.generate(9, (int index) {
              return Center(
                child: Text(
                  '${index + 1}', // Wyświetl liczbę pasażerów (index + 1)
                ),
              );
            }),
          ),
        );
      },
    );
  }

  void _selectDate(BuildContext context, TextEditingController controller, DateTime initialDate) async {
    FocusScope.of(context).requestFocus(new FocusNode());

    final DateTime? pickedDate = await showCupertinoModalPopup<DateTime>(
      context: context,
      // Ustawienia dla iOS
      builder: (BuildContext context) {
        return Container(
          height: 216,
          padding: const EdgeInsets.only(top: 6.0),
          color: CupertinoColors.white,
          child: DefaultTextStyle(
            style: const TextStyle(
              color: CupertinoColors.black,
              fontSize: 22.0,
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: initialDate,
              onDateTimeChanged: (DateTime newDate) {
                if (newDate != initialDate) {
                  controller.text = DateFormat('yyyy-MM-dd').format(newDate);
                }
              },
              minimumYear: DateTime.now().year,
              maximumYear: 2100,
            ),
          ),
        );
      },
    );
  }

  Future<void> fetchSuggestions(String query, bool isDeparture, {int retryCount = 0}) async {
    // Ogranicz liczbę ponownych prób do 3
    if (retryCount >= 3) {
      print('Failed to fetch suggestions after several attempts.');
      return;
    }

    if (query.length < 1) return;

    final keyword = query.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

    try {
      final accessToken = await amadeusApi.getAccessToken();
      final response = await http.get(
        Uri.parse('https://test.api.amadeus.com/v1/reference-data/locations')
            .replace(queryParameters: {
          'subType': 'CITY,AIRPORT',
          'keyword': keyword,
        }),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> suggestions = json.decode(response.body)['data'];
        setState(() {
          if (isDeparture) {
            departureSuggestions = suggestions;
          } else {
            arrivalSuggestions = suggestions;
          }
        });
      } else if (response.statusCode == 429) {
        int delaySeconds = 5 * (2 ^ retryCount); // Wykładnicze opóźnienie
        print('Too many requests, trying again after $delaySeconds seconds...');
        await Future.delayed(Duration(seconds: delaySeconds));
        fetchSuggestions(query, isDeparture, retryCount: retryCount + 1); // Ponów próbę z inkrementowanym licznikiem
      } else {
        print('Error fetching suggestions: ${response.body}');
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  Widget buildSuggestionList(List<dynamic> suggestions, TextEditingController controller) {
    return ListView.builder(
      shrinkWrap: true, // Lista będzie miała rozmiar równy zawartości
      physics: NeverScrollableScrollPhysics(), // Wyłącza przewijanie listy
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return Material(  // Dodaj widget Material tutaj
          child: ListTile(
            title: Text(suggestion['detailedName']),
            subtitle: Text(suggestion['iataCode']), // Pokaż także kod IATA jako podtytuł
            onTap: () {
              controller.text = suggestion['iataCode'];
              // Opróżnij listę sugestii po wybraniu opcji
              if (controller == departureController) {
                setState(() {
                  departureSuggestions = [];
                });
              } else {
                setState(() {
                  arrivalSuggestions = [];
                });
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle:
            Text('Fly Finder', style: TextStyle(color: CupertinoColors.white)),
        // Tytuł w pasku nawigacyjnym
        backgroundColor:
            CupertinoColors.systemBlue, // Kolor tła paska nawigacyjnego
      ),
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 16),
        // Minimalny margines poziomy dla bezpiecznego obszaru
        child: SingleChildScrollView(
          // Widget umożliwiający przewijanie
          child: Column(
            // Kolumna do organizowania widgetów pionowo
            crossAxisAlignment: CrossAxisAlignment.start,
            // Wyrównanie do lewej strony
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Miejsce odlotu',
                    style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors
                            .black)), // Tytuł dla pola "Departure City"
                ),
              CupertinoTextField(
                controller: departureController,
                placeholder: 'e.g., New York',
                onChanged: (value) => onSearchChanged(value, true),
                clearButtonMode: OverlayVisibilityMode.editing,
                decoration: BoxDecoration(
                  border:
                      Border.all(color: CupertinoColors.separator, width: 0.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              buildSuggestionList(departureSuggestions, departureController),
              // Lista sugestii dla miasta wylotu
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Miejsce przybycia',
                    style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors
                            .black)), // Tytuł dla pola "Arrival City"
                ),
              CupertinoTextField(
                controller: arrivalController,
                placeholder: 'e.g., Paris',
                onChanged: (value) => onSearchChanged(value, false),
                clearButtonMode: OverlayVisibilityMode.editing,
                decoration: BoxDecoration(
                  border:
                      Border.all(color: CupertinoColors.separator, width: 0.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              buildSuggestionList(arrivalSuggestions, arrivalController),
              // Lista sugestii dla miasta przylotu
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Wybierz datę odlotu',
                    style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors
                            .black)), // Tytuł dla pola "Departure Date"
              ),
              CupertinoTextField(
                controller: departureDateController,
                placeholder: 'Data odlotu',
                readOnly: true,
                onTap: () => _selectDate(
                  context,
                  departureDateController,
                  departureDateController.text.isNotEmpty
                      ? DateFormat('yyyy-MM-dd')
                          .parse(departureDateController.text)
                      : DateTime.now(),
                ),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: CupertinoColors.separator, width: 0.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Wybierz datę przylotu',
                    style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors
                            .black)), // Tytuł dla pola "Return Date"
              ),
              CupertinoTextField(
                controller: returnDateController,
                placeholder: 'Data przylotu',
                readOnly: true,
                onTap: () => _selectDate(
                  context,
                  returnDateController,
                  returnDateController.text.isNotEmpty
                      ? DateFormat('yyyy-MM-dd')
                          .parse(returnDateController.text)
                      : DateTime.now(),
                ),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: CupertinoColors.separator, width: 0.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Ilość pasażerów',
                    style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors
                            .black)), // Tytuł dla pola "Number of Passengers"
              ),
              CupertinoTextField(
                controller: passengerCountController,
                keyboardType: TextInputType.number,
                placeholder: '1',
                readOnly: true,
                onTap: () => _showPassengerPicker(context),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: CupertinoColors.separator, width: 0.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: _isLoading // Zmienna kontrolująca stan ładowania
                    ? Center(
                        child:
                            CupertinoActivityIndicator()) // Animacja ładowania
                    : Center(
                        child: CupertinoButton(
                          color: CupertinoColors.activeBlue,
                          onPressed: performSearch,
                          child: Text('Szukaj'),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
              ),
              //Wyswietlenie listy lotów jeśi są dostępne
              Visibility(
                visible: directFlights.isNotEmpty,
                child: buildFlightList(directFlights, "Loty bezpośrednie"),
              ),
// Pokazuje listę lotów z przesiadkami, jeśli są dostępne
              Visibility(
                visible: connectingFlights.isNotEmpty,
                child: buildFlightList(connectingFlights, "Loty z przesiadką"),
              ),
              SizedBox(height: 10),
// Warunkowe wyświetlanie wyników wyszukiwania, jeśli są dostępne
              if (searchResults.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: searchResults.length,
                  itemBuilder: (BuildContext context, int index) {
                    final result = searchResults[index];
                    return FlightCard(
                        flight:
                            result); // Wyświetlanie karty lotu dla każdego wyniku
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildFlightList(List<Map<String, dynamic>> flights, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Otocz nagłówek widgetem Material i ustaw przezroczyste tło
        Material(
          color: Colors.transparent, // Ustaw przezroczyste tło
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.black, // Ustaw kolor tekstu na czarny
              ),
            ),
          ),
        ),
        ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: flights.length,
          itemBuilder: (BuildContext context, int index) {
            return FlightCard(flight: flights[index]); // Użyj FlightCard lub innego widgetu
          },
        ),
      ],
    );
  }

}



