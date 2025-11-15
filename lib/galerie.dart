import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:conversion/conversion.dart';
import 'UserStore.dart';
import 'slidehistory.dart';
import 'NavigationScreen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image/flutter_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GalleryEntry {
  String? link;

  GalleryEntry({this.link});

  static List<GalleryEntry> fromJson(List<dynamic> jsonList) {
    return jsonList.map((json) => GalleryEntry(link: json.toString())).toList();
  }
}

class Galerie extends StatefulWidget {
  const Galerie({super.key});
  //const Galerie({super.key});
  //const Galerie({super.key});

  @override
  _GalerieState createState() => _GalerieState();
}

class _GalerieState extends State<Galerie> {
  bool _noInternet = false; // <— hinzugefügt: Zustand für Internetfehler
  Widget _refreshableInfo(String message, double h) {
    return SizedBox(
      height: h * 0.61,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: h * 0.25),
        children: [
          Center(child: Text(message)),
        ],
      ),
    );
  }

  Future<List<GalleryEntry>> populateGallery() async {
    /*final prefs = await SharedPreferences.getInstance();
    String cook = prefs.getString('cookie') ?? "";*/
    try {
      final response = await http.get(
        Uri.parse('https://waterslide.works/app/images'),
        // Send authorization headers to the backend.
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': Provider.of<UserStore>(context, listen: false).cookie,
        },
      );
      print(response.body);

      // Wenn erfolgreich geladen, Internet-Flag zurücksetzen
      if (_noInternet) {
        setState(() {
          _noInternet = false;
        });
      }

      try {
        final List responseJson = jsonDecode(response.body)['data'];
        // Leere Liste explizit erlauben – wird unten im UI behandelt
        return GalleryEntry.fromJson(responseJson);
      } catch (e) {
        final List<GalleryEntry> list = [GalleryEntry(link: "")];
        return list;
      }
    } on SocketException catch (_) {
      // Keine Internetverbindung
      setState(() {
        _noInternet = true;
      });
      // SnackBar nach dem Frame anzeigen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: const Duration(seconds: 2), // auto-dismiss

              content: Text('Keine Internetverbindung'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
      return <GalleryEntry>[];
    }
  }

  Future<void> _refreshData() async {
    try {
      // API-Aufruf oder Logik zum Abrufen der neuen Daten
      final newEntries = await populateGallery(); // Beispiel für API-Aufruf

      // UI aktualisieren mit neuen Daten
      setState(() {
        entries = Future.value(newEntries);
      });

      // Wenn leer (aber Internet vorhanden), kein SnackBar – nur Text im UI
      // Wenn _noInternet true, wurde SnackBar bereits in populateGallery gezeigt
    } on SocketException catch (_) {
      // Fallback – sollte durch populateGallery schon abgefangen sein
      setState(() {
        _noInternet = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Internetverbindung'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Andere Fehler
      print("Fehler beim Aktualisieren der Daten: $e");
    }
  }

  late Future<List<GalleryEntry>> entries; //= populateGallery();
  //String? cookie;

  @override
  void initState() {
    super.initState();
    entries = populateGallery();
    //getcookie();
  }

  /*Future<void> getcookie() async {
    final prefs = await SharedPreferences.getInstance();
    final String cook = prefs.getString('cookie') ?? "";
    setState(() {
      cookie = cook;
    });
  }*/

  Future<void> _shareImage(String imageUrl) async {
    try {
      // Lade das Bild herunter
      final response = await http.get(Uri.parse(imageUrl), headers: {
        'Cookie': Provider.of<UserStore>(context, listen: false).cookie
      });
      final bytes = response.bodyBytes;

      // Speicher das Bild im temporären Verzeichnis
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/shared_image.jpg');
      await file.writeAsBytes(bytes);

      // Teile das Bild mit shareXFiles
      XFile xFile = XFile(file.path); // Erstellt ein XFile-Objekt
      await Share.shareXFiles([xFile], text: 'Schau dir dieses tolle Foto an!');
    } catch (e) {
      print('Fehler beim Teilen des Bildes: $e');
    }
  }

  bool _isZoomed = false; // Zustand, ob das Bild vergrößert ist
  String? _zoomedImageUrl; // Zustand, ob das Bild vergrößert ist
  List<String> items = [
    "Item 1",
    "Item 2",
    "Item 3",
    "Item 4",
    "",
    "",
    "",
    "",
  ];
  @override
  @override
  Widget build(BuildContext context) {
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
                    Container(
                      height: h * 0.39,
                      child: Stack(children: [
                        Positioned(
                          left: w * 0.7,
                          top: 30,
                          height: h * 0.10,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Image(
                                  image: AssetImage('assets/new_mayamare.png'),
                                  width: 150,
                                  height: 150,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: h * 0.16),
                              child: Center(
                                child: Container(
                                  width: w * 0.7,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: w * 0.7,
                                        child: Consumer<UserStore>(
                                          builder: (context, value, child) =>
                                              Text(
                                            'Hallo, ${value.user} !',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w500,
                                              height: 0.08,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                top: h * 0.01,
                              ),
                              child: Center(
                                child: Container(
                                  width: w * 0.7,
                                  height: h * 0.1,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: w * 0.7,
                                        child: Text(
                                          'Galerie',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 32,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(bottom: h * 0.01),
                              child: Center(
                                  child: Container(
                                width: 0.7 * w,
                                height: h * 0.08,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 0.7 * w,
                                      height: h * 0.14,
                                      child: Text(
                                        'Sieh dir deine Fotos an und erlebe die besten Momente noch einmal!',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w500,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            )
                          ],
                        )
                      ]),
                    ),
                    Container(
                      child: FutureBuilder<List<GalleryEntry>>(
                        future: entries,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 100),
                              child: const CircularProgressIndicator(),
                            );
                          } else if (snapshot.hasData) {
                            final entries = snapshot.data!;

                            // Neu: Anzeige bei keiner Internetverbindung
                            if (_noInternet) {
                              return _refreshableInfo(
                                  'Keine Internetverbindung', h);
                            }

                            // Neu: Anzeige bei leerer Liste
                            if (entries.isEmpty ||
                                (entries.length == 1 &&
                                    (entries.first.link == null ||
                                        entries.first.link == ""))) {
                              return _refreshableInfo(
                                  'Sie ziemlich leer aus hier', h);
                            }

                            return Container(
                              height: h * 0.61,
                              decoration: ShapeDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1, -0.8),
                                  end: Alignment(0.85, 0.95),
                                  colors: [Colors.white, Color(0xFFDCDCDC)],
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
                                  )
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // GridView mit den Bildern
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        width: w * 0.7,
                                        height: h * 0.45 + 30,
                                        child: GridView.builder(
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount:
                                                2, // Anzahl der Spalten im Grid
                                            crossAxisSpacing: 10,
                                            mainAxisSpacing: 10,
                                          ),
                                          itemCount: entries
                                              .length, // Anzahl der Bilder
                                          itemBuilder: (context, index) {
                                            final entry = entries[index];

                                            String imageUrl = entry.link != ""
                                                ? 'https://waterslide.works${entry.link}'
                                                : "https://picsum.photos/250?image=9";

                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _isZoomed = true;
                                                  _zoomedImageUrl = imageUrl;
                                                });
                                              },
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: CachedNetworkImage(
                                                  imageUrl: imageUrl,
                                                  httpHeaders: {
                                                    'Cookie':
                                                        Provider.of<UserStore>(
                                                                context,
                                                                listen: false)
                                                            .cookie
                                                  },
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Icon(Icons.error),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Zoomed Image overlay (wenn ein Bild angeklickt wird)
                                  if (_isZoomed)
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isZoomed = false;
                                            _zoomedImageUrl = null;
                                          });
                                        },
                                        child: Container(
                                          decoration: ShapeDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment(-1, -0.8),
                                              end: Alignment(0.85, 0.95),
                                              colors: [
                                                Color(0xFFFDFDFD),
                                                Color(0xFFE0E0E0)
                                              ],
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
                                              )
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.only(
                                                    top: w * 0.15),
                                                child: Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            40),
                                                    child: CachedNetworkImage(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.7,
                                                      height:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height *
                                                              0.35,
                                                      imageUrl:
                                                          _zoomedImageUrl!,
                                                      httpHeaders: {
                                                        'Cookie': Provider.of<
                                                                    UserStore>(
                                                                context,
                                                                listen: false)
                                                            .cookie
                                                      },
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (context, url) =>
                                                              Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Icon(Icons.error),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 15),
                                                child: Container(
                                                    width: w * 0.7,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween, // Gleichmäßiger Abstand zwischen den Buttons
                                                      children: [
                                                        // Zurück-Button
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  50), // Runde Ecken
                                                          child: Container(
                                                            width: 70,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Color(
                                                                      0xFFD9D9D9)
                                                                  .withOpacity(
                                                                      0.30), // Hintergrundfarbe mit Opazität
                                                            ),
                                                            child: IconButton(
                                                              icon: Icon(
                                                                Icons
                                                                    .arrow_back,
                                                                color: Colors
                                                                    .black, // Icon bleibt schwarz
                                                              ),
                                                              onPressed: () {
                                                                setState(() {
                                                                  _isZoomed =
                                                                      false;
                                                                  _zoomedImageUrl =
                                                                      null;
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                        ),

                                                        // Teilen-Button
                                                        // Herz-Button (Favoriten)
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  50), // Runde Ecken
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Color(
                                                                      0xFFD9D9D9)
                                                                  .withOpacity(
                                                                      0.30), // Hintergrundfarbe mit Opazität
                                                            ),
                                                            child: IconButton(
                                                              icon: Icon(
                                                                Icons.share,
                                                                color: Colors
                                                                    .black, // Icon bleibt schwarz
                                                              ),
                                                              onPressed: () {
                                                                if (_zoomedImageUrl !=
                                                                    null) {
                                                                  _shareImage(
                                                                      _zoomedImageUrl!); // Teilen der Bild-URL
                                                                }
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    )),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          } else if (snapshot.hasError) {
                            // Generischer Fehlerfall
                            return Container(
                              height: h * 0.61,
                              alignment: Alignment.center,
                              child: const Text('Fehler beim Laden'),
                            );
                          } else {
                            return const Text("No data available");
                          }
                        },
                      ),
                    ),
                  ],
                ),
              )));
    });
  }
}

typedef DecoderCallback = Future<ui.Codec> Function(Uint8List bytes,
    {int? cacheWidth, int? cacheHeight, bool allowUpscaling});

class NetworkImageWithHeaders extends ImageProvider<NetworkImageWithHeaders> {
  final String url;
  final Map<String, String>? headers;

  const NetworkImageWithHeaders(this.url, {this.headers});

  @override
  Future<NetworkImageWithHeaders> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NetworkImageWithHeaders>(this);
  }

  @override
  ImageStreamCompleter load(
      NetworkImageWithHeaders key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield ErrorDescription('Bild-URL: $url');
      },
    );
  }

  Future<ui.Codec> _loadAsync(
      NetworkImageWithHeaders key, DecoderCallback decode) async {
    assert(key == this);

    try {
      final Uri resolved = Uri.base.resolve(key.url);
      final http.Response response = await http.get(resolved, headers: headers);
      if (response.statusCode != 200) {
        throw Exception(
            'HTTP-Anfrage fehlgeschlagen, StatusCode: ${response.statusCode}, $resolved');
      }
      final Uint8List bytes = response.bodyBytes;
      if (bytes.lengthInBytes == 0) {
        throw Exception(
            'NetworkImageWithHeaders ist eine leere Datei: $resolved');
      }

      return await decode(bytes);
    } catch (e) {
      // Fehlerbehandlung
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is NetworkImageWithHeaders &&
        other.url == url &&
        mapEquals(other.headers, headers);
  }

  @override
  int get hashCode => Object.hash(url, headers);

  @override
  String toString() => '$runtimeType("$url", headers: $headers)';
}
