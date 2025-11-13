import 'dart:core';
import 'dart:io'; // Für SocketException

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accountmenu.dart';
import 'commonfunctions.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'signup.dart';
import 'commonfunctions.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:conversion/conversion.dart';
import 'UserStore.dart';
import 'slidehistory.dart';
import 'NavigationScreen.dart';
import 'bestenlistetop.dart';

class Bestenliste extends StatefulWidget {
  const Bestenliste({super.key, required this.rutschliste});

  final List<Slides> rutschliste;

  @override
  _BestenlisteState createState() => _BestenlisteState();
}

class _BestenlisteState extends State<Bestenliste>
    with AutomaticKeepAliveClientMixin<Bestenliste> {
  late Future<List<Slideentry>> entryFuture;
  bool isPending = false;
  List<String> rankinglist = [
    "Top 10",
    "Meine Zeiten",
  ];
  String? selectedSlide;
  String? selectedRanking;
  bool maximize = false;

  // === NEU: Scrollbarer Platzhalter für Refresh in leeren/Fehler-Zuständen ===
  Widget _refreshableInfo(String message, double boxHeight) {
    return SizedBox(
      height: boxHeight,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: boxHeight / 2 - 12),
        children: [
          Center(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Slideentry>> populateEntries(String? id) async {
    try {
      final response = await http.get(
        Uri.parse('https://waterslide.works/app/top10/day/$id'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': Provider.of<UserStore>(context, listen: false).cookie,
        },
      );

      if (response.statusCode != 200) {
        // Bei Nicht-200 als leere Liste behandeln (kein Layout-Bruch)
        return <Slideentry>[];
      }

      final List responseJson = jsonDecode(response.body);
      for (var eintrag in responseJson) {
        eintrag['text'] = "";
      }
      return responseJson.map((e) => Slideentry.fromJson(e)).toList();
    } on SocketException {
      // Deutlich signalisieren: keine Internetverbindung
      throw const SocketException('NO_INTERNET');
    } catch (_) {
      // Andere Fehler unauffällig als leere Liste zurückgeben
      return <Slideentry>[];
    }
  }

  Future<List<Slideentry>> populateMyEntries(String? id) async {
    try {
      final response = await http.get(
        Uri.parse('https://waterslide.works/app/mytimes/$id'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': Provider.of<UserStore>(context, listen: false).cookie,
        },
      );

      if (response.statusCode != 200) {
        return <Slideentry>[];
      }

      List responseJson = jsonDecode(response.body)['data'];
      for (var eintrag in responseJson) {
        eintrag['username'] = "";
      }
      return responseJson.map((e) => Slideentry.fromJson(e)).toList();
    } on SocketException {
      throw const SocketException('NO_INTERNET');
    } catch (_) {
      return <Slideentry>[];
    }
  }

  Future<void> _refreshData() async {
    try {
      if (selectedRanking == "Top 10") {
        final newEntries = await populateEntries(selectedSlide);
        setState(() {
          entryFuture = Future.value(newEntries);
        });
      } else {
        final newEntries = await populateMyEntries(selectedSlide);
        setState(() {
          entryFuture = Future.value(newEntries);
        });
      }
    } catch (e) {
      // Keine UI-Änderung hier – FutureBuilder zeigt Fehlertext.
      // Nur Logging:
      // ignore: avoid_print
      print("Fehler beim Aktualisieren der Daten: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    selectedSlide = widget.rutschliste[0].id;
    selectedRanking = rankinglist[0];
    entryFuture = populateEntries(selectedSlide);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      double w = constraints.maxWidth;
      double h = constraints.maxHeight;
      return Scaffold(
          body: RefreshIndicator(
              onRefresh: _refreshData,
              child: Container(
                color: const Color(0xFFEAEAEA),
                child: Column(
                  children: [
                    maximize == false
                        ? BestenListeTop(h: h, w: w)
                        : Container(
                            height: 0.05 * h,
                          ),
                    Container(
                      height: maximize == false ? h * 0.61 : h * 0.95,
                      child: GestureDetector(
                        onVerticalDragEnd: (details) {
                          if (details.primaryVelocity! < 0) {
                            setState(() {
                              maximize = true;
                            });
                          } else if (details.primaryVelocity! > 0) {
                            setState(() {
                              maximize = false;
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 1000),
                          curve: Curves.easeInOut,
                          height: maximize ? h * 0.95 : h * 0.61,
                          decoration: ShapeDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1, -0.8),
                              end: Alignment(0.85, 0.95),
                              colors: [Color(0xFFFDFDFD), Color(0xFFE0E0E0)],
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(50),
                                topRight: Radius.circular(50),
                              ),
                            ),
                            shadows: [
                              BoxShadow(
                                color: Color(0x3F000000),
                                blurRadius: 4,
                                offset: Offset(0, 4),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    maximize = !maximize;
                                  });
                                },
                                icon: maximize
                                    ? Icon(Icons.fullscreen_exit)
                                    : Icon(Icons.fullscreen),
                              ),
                              Container(
                                padding: EdgeInsets.only(top: h * 0.02),
                                child: SizedBox(
                                  width: 260,
                                  height: 30,
                                  child: Text(
                                    'Wähle eine Rutsche',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w600,
                                      height: 0.08,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding:
                                    EdgeInsets.only(left: w * 0.15, bottom: 10),
                                height: 50,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: widget.rutschliste.length,
                                  itemBuilder: (context, index) {
                                    final entry = widget.rutschliste[index];

                                    return entry.name != "Error"
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: Container(
                                              decoration: ShapeDecoration(
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(width: 1),
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                ),
                                              ),
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      selectedSlide == entry.id
                                                          ? Color(0xFFD9D9D9)
                                                          : Colors.white,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    selectedSlide = entry.id;
                                                    if (selectedRanking ==
                                                        "Top 10") {
                                                      entryFuture =
                                                          populateEntries(
                                                              entry.id);
                                                    } else {
                                                      entryFuture =
                                                          populateMyEntries(
                                                              entry.id);
                                                    }
                                                  });
                                                },
                                                child: Center(
                                                  child: Text(
                                                    '${entry.name}',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 16,
                                                      fontFamily: 'Montserrat',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            "Error, ausloggen und wieder einloggen");
                                  },
                                ),
                              ),
                              Container(
                                padding:
                                    EdgeInsets.only(left: w * 0.15, bottom: 10),
                                height: 50,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: rankinglist.length,
                                  itemBuilder: (context, index) {
                                    final entryrank = rankinglist[index];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        decoration: ShapeDecoration(
                                          color: Color(0xFFD9D9D9),
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(width: 1),
                                            borderRadius:
                                                BorderRadius.circular(50),
                                          ),
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                selectedRanking == entryrank
                                                    ? Color(0xFFD9D9D9)
                                                    : Colors.white,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              selectedRanking = entryrank;
                                              if (entryrank == "Top 10") {
                                                entryFuture = populateEntries(
                                                    selectedSlide);
                                              } else {
                                                entryFuture = populateMyEntries(
                                                    selectedSlide);
                                              }
                                            });
                                          },
                                          child: Text(
                                            entryrank,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600,
                                              height: 0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              FutureBuilder<List<Slideentry>>(
                                future: entryFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  } else if (snapshot.hasError) {
                                    final double boxHeight =
                                        maximize ? h * 0.62 : h * 0.29;
                                    // Scrollbarer Fehlerzustand -> Pull-to-Refresh
                                    return _refreshableInfo(
                                      "Keine Internetverbindung",
                                      boxHeight,
                                    );
                                  } else if (snapshot.hasData) {
                                    final entries = snapshot.data!;
                                    if (entries.isEmpty) {
                                      final double boxHeight =
                                          maximize ? h * 0.62 : h * 0.29;
                                      // Scrollbarer Leerzustand -> Pull-to-Refresh
                                      return _refreshableInfo(
                                        "Hier sieht es ganz schön leer aus",
                                        boxHeight,
                                      );
                                    }
                                    return Container(
                                      height: maximize ? h * 0.62 : h * 0.29,
                                      child: buildEntries(entries, w, h),
                                    );
                                  } else {
                                    // Fallback – neutral, ebenfalls scroll-/refresh-fähig
                                    final double boxHeight =
                                        maximize ? h * 0.62 : h * 0.29;
                                    return _refreshableInfo(
                                      "Hier sieht es ganz schön leer aus",
                                      boxHeight,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )));
    });
  }

  Widget buildEntries(List<Slideentry> entries, double w, double h) {
    return ListView.builder(
      itemCount: entries.length,
      padding: EdgeInsets.only(bottom: 20),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return selectedRanking == "Top 10"
            ? Container(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: 0.3,
                        child: Container(
                          width: w * 0.7,
                          decoration: ShapeDecoration(
                            color: Color(0xFFD9D9D9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          margin:
                              EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          padding:
                              EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                          height: 55,
                        ),
                      ),
                      Container(
                        width: w * 0.7,
                        height: 55,
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 3.5, bottom: 3.5, left: 10),
                              child: SizedBox(
                                width: 20,
                                child: Text(
                                  "${index + 1}",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w600,
                                    height: 0,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              child: Opacity(
                                  opacity: 0.7,
                                  child: CircleAvatar(
                                    backgroundColor: Color(0xFFD9D9D9),
                                    radius: 40,
                                  )),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding:
                                        EdgeInsets.only(top: 10, bottom: 20),
                                    child: Text(
                                      "${entry.user}",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        height: 0.08,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    child: Text(
                                      "${entry.time?.toStringAsFixed(2) ?? "0.00"}s / ${entry.speed?.toStringAsFixed(2) ?? "0.00"}km/h / ${entry.points} Pkt.",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 11,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w500,
                                        height: 0.08,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : index == 0
                ? Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "Deine Bestzeit",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                            height: 0.08,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Stack(
                            children: [
                              Opacity(
                                opacity: 0.3,
                                child: Container(
                                  width: w * 0.7,
                                  decoration: ShapeDecoration(
                                    color: Color(0xFFD9D9D9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  ),
                                  margin: EdgeInsets.symmetric(
                                      vertical: 5, horizontal: 10),
                                  padding: EdgeInsets.symmetric(
                                      vertical: 5, horizontal: 5),
                                  height: 55,
                                ),
                              ),
                              Container(
                                width: w * 0.7,
                                height: 55,
                                margin: EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                padding: EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 5),
                                child: Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        child: Text(
                                          "${entry.time?.toStringAsFixed(2) ?? "0.00"}s / ${entry.speed?.toStringAsFixed(2) ?? "0.00"}km/h / ${entry.points} Pkt.",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 13,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                            height: 0.08,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 12.0),
                                        child: SizedBox(
                                          child: Text(
                                            '${entry.text}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w500,
                                              height: 0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "Alle Zeiten",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                            height: 0.08,
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Stack(
                        children: [
                          Opacity(
                            opacity: 0.3,
                            child: Container(
                              width: w * 0.7,
                              decoration: ShapeDecoration(
                                color: Color(0xFFD9D9D9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              margin: EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              padding: EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 5),
                              height: 55,
                            ),
                          ),
                          Container(
                            width: w * 0.7,
                            height: 55,
                            margin: EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            padding: EdgeInsets.symmetric(
                                vertical: 5, horizontal: 5),
                            child: Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    child: Text(
                                      "${entry.time?.toStringAsFixed(2) ?? "0.00"}s / ${entry.speed?.toStringAsFixed(2) ?? "0.00"}km/h / ${entry.points} Pkt.",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        height: 0.08,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: SizedBox(
                                      child: Text(
                                        '${entry.text}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w500,
                                          height: 0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
      },
    );
  }
}
