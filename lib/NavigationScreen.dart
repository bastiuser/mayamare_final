import 'package:flutter/material.dart';
import 'package:flutter_application_wead/bestenliste.dart';
import 'package:flutter_application_wead/galerie.dart';
import 'package:flutter_application_wead/login.dart';
import 'package:flutter_application_wead/mainpage.dart';
import 'package:flutter_application_wead/nfcscanner.dart';
import 'package:flutter_application_wead/profile.dart';
import 'package:flutter_application_wead/slidehistory.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accountmenu.dart';
import 'commonfunctions.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'signup.dart';
import 'commonfunctions.dart';
import 'package:floating_bottom_navigation_bar/floating_bottom_navigation_bar.dart';
import 'slidepicker.dart';

class CustomScrollPhysics extends ScrollPhysics {
  final double deadzoneSize;

  CustomScrollPhysics({ScrollPhysics? parent, this.deadzoneSize = 15.0})
      : super(parent: parent);

  @override
  CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomScrollPhysics(
        parent: buildParent(ancestor), deadzoneSize: deadzoneSize);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Füge eine Deadzone hinzu: nur wenn die Bewegung größer ist als deadzoneSize, wird gescrollt
    if (offset.abs() < deadzoneSize) {
      return 0.0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double frictionFactor(double overscrollFraction) {
    // Reduziere die Empfindlichkeit des Scrollens
    return 0.5; // Je kleiner dieser Wert, desto weniger sensibel ist das Scrollen
  }
}

class Slides {
  String? id;
  String? name;

  Slides({this.id, this.name});

  Slides.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late Future<List<Slides>> entryFuture;

  int _selectedIndex = 1;
  late PageController _pageController;

  // Animationseigenschaften
  double _backgroundPosition = 1; // Startet bei Index 1
  Future<List<Slides>> populate() async {
    print("Cookie:${Provider.of<UserStore>(context, listen: false).cookie}");

    /*final prefs = await SharedPreferences.getInstance();
    String cook = prefs.getString('cookie') ?? "";
    print(cook);*/
    final response = await http.get(
      Uri.parse('https://waterslide.works/app/rutschen'),
      // Send authorization headers to the backend.
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Cookie': Provider.of<UserStore>(context, listen: false).cookie,
      },
    );

    try {
      final List responseJson = jsonDecode(response.body)['data'];

      return responseJson.map((e) => Slides.fromJson(e)).toList();
    } catch (e) {
      final List<Slides> list = [Slides(id: "Error", name: "Error")];
      return list;
    }
  }

  @override
  void initState() {
    super.initState();
    UserStore current = Provider.of<UserStore>(context, listen: false);
    if (current.landing) {
      setState(() {
        _selectedIndex = 0;
        _backgroundPosition = 0;
      });
    }
    _pageController = PageController(initialPage: _selectedIndex);
    entryFuture = populate();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _backgroundPosition =
          index.toDouble(); // Position des Hintergrunds aktualisieren
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Berechnung der Breite jedes Icons (Breite der BottomNavigationBar ist 70% der Bildschirmbreite)
    double iconWidth = MediaQuery.of(context).size.width * 0.7 / 4;
    List<Widget> _widgetOptions = <Widget>[
      FutureBuilder<List<Slides>>(
        future: entryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            // Hier die Bestenliste mit den geladenen Daten anzeigen
            return Bestenliste(rutschliste: snapshot.data!);
          } else {
            return Center(child: Text('No data available'));
          }
        },
      ),
      NFCscanner(),
      Galerie(),
      Slidepicker()
    ];
    return Scaffold(
      body: Stack(
        children: [
          // PageView für den Seiteninhalt
          PageView(
            controller: _pageController,
            physics: CustomScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
                _backgroundPosition =
                    index.toDouble(); // Position des Hintergrunds aktualisieren
              });
            },
            children: _widgetOptions,
          ),
          // NavigationBar mit animiertem Hintergrund, die auf dem Inhalt schwebt
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                  bottom: 5), // Platz für die NavigationBar
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40.0), // Abgerundete Ecken
                child: Container(
                  height: 52, // Höhe der NavigationBar
                  width: MediaQuery.of(context).size.width *
                      0.7, // 70% der Bildschirmbreite
                  decoration: BoxDecoration(
                    color: Color(0xFFD9D9D9),
                    // Einheitliche Hintergrundfarbe der NavigationBar
                    borderRadius:
                        BorderRadius.circular(40), // Abgerundete Ecken
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Animierter gleitender Hintergrund unter den Icons
                      AnimatedPositioned(
                        top: 6,
                        left: iconWidth * _backgroundPosition + 4,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Container(
                          width: MediaQuery.of(context).size.width > 550
                              ? 60 +
                                  MediaQuery.of(context).size.width / 730 * 60
                              : 60,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(
                                0xFFB8B8B8), // Hintergrund des ausgewählten Icons
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),
                      // BottomNavigationBar mit einer festen Hintergrundfarbe und statischen Icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          buildNavBarItem(
                              icon: Icons.emoji_events_outlined,
                              index: 0,
                              iconWidth: iconWidth),
                          buildNavBarItem(
                              icon: Icons.watch_outlined,
                              index: 1,
                              iconWidth: iconWidth),
                          buildNavBarItem(
                              icon: Icons.image_outlined,
                              index: 2,
                              iconWidth: iconWidth),
                  
                          buildNavBarItem(
                              icon: Icons.airline_seat_flat_angled_outlined,
                              index: 3,
                              iconWidth: iconWidth),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hilfsmethode zum Erstellen der NavBar-Icons
  Widget buildNavBarItem(
      {required IconData icon, required int index, required double iconWidth}) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        width: iconWidth,
        height: 52,
        alignment: Alignment.center,
        child: Icon(icon,
            size: 24, // Größeres Icon für das ausgewählte Element
            color: Colors.black
            // Farbänderung für ausgewähltes Icon
            ),
      ),
    );
  }
}
