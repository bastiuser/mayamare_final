import 'dart:async';
import 'dart:convert';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_wead/accountmenu.dart';
import 'package:flutter_application_wead/mainpage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'signup.dart';
import 'UserStore.dart';
import 'InputBoxForm.dart';
import 'package:image_picker/image_picker.dart'; // Für den Zugriff auf die Galerie

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  ProfileState createState() {
    return ProfileState();
  }
}

class ProfileState extends State<Profile>
    with AutomaticKeepAliveClientMixin<Profile> {
  final _formKey = GlobalKey<FormState>();
  final _usernamecontroller = TextEditingController();
  final _passController = TextEditingController();

  final _emailcontroller = TextEditingController();

  File? _image; // Hier wird das ausgewählte Bild gespeichert
  void _showErrorSnack(String message) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating, // wirkt „leichter“ und auffälliger
          margin: const EdgeInsets.all(12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: cs.error, // knallrot aus Theme
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.error_outline, color: cs.onError),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: cs.onError), // hoher Kontrast auf Rot
                ),
              ),
            ],
          ),
        ),
      );
  }

  // Methode, um das Bild aus der Galerie zu wählen
  Future<void> _pickImage() async {
    final prefs = await SharedPreferences.getInstance();
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      prefs.setString('profile', pickedFile.path);
      setState(() {
        _image = File(pickedFile.path); // Bild im Zustand speichern
      });
    }
  }

  Future<void> deleteAccount() async {
    http.Response response;
    try {
      response = await http.post(
        Uri.parse('https://waterslide.works/app/deleteuser'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': Provider.of<UserStore>(context, listen: false).cookie,
        },
      );
    } on TimeoutException {
      _showErrorSnack(
          'Zeitüberschreitung beim Löschen. Bitte später erneut versuchen.');
      rethrow;
    } on SocketException {
      _showErrorSnack('Keine Internetverbindung. Prüfe dein Netzwerk.');
      rethrow;
    } catch (e) {
      _showErrorSnack('Unerwarteter Fehler beim Löschen.');
      rethrow;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _showErrorSnack(
          'Anmeldung fehlgeschlagen (HTTP ${response.statusCode}).');
    }

    Map<String, dynamic> responseJson;
    responseJson = jsonDecode(response.body) as Map<String, dynamic>;

    final apiSuccess = responseJson['success'];
    if (apiSuccess) {
      _showErrorSnack("Erfolgreich gelöscht");
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Provider.of<UserStore>(context, listen: false).clearAll();
      context.go('/');
    }
    if (apiSuccess is bool && apiSuccess == false) {
      final serverMsg =
          (responseJson['message'] ?? 'Anmeldung fehlgeschlagen.') as String;
      _showErrorSnack(serverMsg);
      throw StateError('API login failed: $serverMsg');
    }
  }

  Future<void> _getImage() async {
    final prefs = await SharedPreferences.getInstance();
    final String image = prefs.getString('profile') ?? "";
    if (image != "") {
      setState(() {
        _image = File(image);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getImage();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true, // damit der Gradient bis oben geht
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            // Wenn du GoRouter nutzt:
            onPressed: () => context.pop(),
            // Alternativ (ohne GoRouter):
            // onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            double w = constraints.maxWidth;
            double h = constraints.maxHeight;

            return Column(
              children: [
                Container(
                    color: Color(0xFFEAEAEA),
                    child: Container(
                      height: h * 1, // Maximiert bei Fokus
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1, -0.8),
                          end: Alignment(0.85, 0.95),
                          colors: [Colors.white, Color(0xFFDCDCDC)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(50),
                          topRight: Radius.circular(50),
                        ),
                      ),

                      child: Padding(
                        padding: EdgeInsets.only(top: h * 0.1),
                        child: Column(
                          children: [
                            Container(
                              height: h * 0.3,
                              child: Center(
                                child: Stack(
                                  children: [
                                    // Kreisförmiges Profilbild oder Platzhalter
                                    Padding(
                                        padding: const EdgeInsets.only(top: 90),
                                        child: InkWell(
                                          onTap: _pickImage,
                                          child: Opacity(
                                              opacity: _image != null ? 1 : 0.3,
                                              child: CircleAvatar(
                                                backgroundColor:
                                                    Color(0xFFD9D9D9),
                                                radius: 75, // Größe des Kreises
                                                backgroundImage: _image != null
                                                    ? FileImage(
                                                        _image!) // Wenn ein Bild ausgewählt wurde
                                                    : null, // Wenn kein Bild ausgewählt wurde
                                                child: _image == null
                                                    ? Icon(
                                                        Icons.person,
                                                        size: 50,
                                                        color: Colors.black,
                                                      ) // Platzhalter-Icon
                                                    : null,
                                              )),
                                        )),
                                    // Stift-Icon zum Auswählen des Bildes
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: InkWell(
                                        onTap:
                                            _pickImage, // Bildauswahl aus der Galerie
                                        child: CircleAvatar(
                                          radius: 25,
                                          backgroundColor: Colors.grey[300],
                                          child: Icon(Icons.edit, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: h * 0.06),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Center(
                                        child: SizedBox(
                                            width: 0.7 * w,
                                            height: 12 +
                                                0.05 *
                                                    h, // kann auch über contentPadding gesteuert werden
                                            child: InputDecorator(
                                              isFocused: false,
                                              isEmpty:
                                                  _emailcontroller.text.isEmpty,
                                              decoration: InputDecoration(
                                                suffixIcon: const Padding(
                                                  padding: EdgeInsets.all(10.0),
                                                  child: Icon(Icons.person),
                                                ),
                                                // WICHTIG: labelText/labelStyle weglassen, wenn "label" (Widget) genutzt wird
                                                label: Consumer<UserStore>(
                                                  builder:
                                                      (context, value, _) =>
                                                          Text(
                                                    '   ${value.user}', // Username als Label
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      fontFamily: 'Montserrat',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          32.0),
                                                  borderSide: const BorderSide(
                                                      color: Colors.black,
                                                      width: 1.3),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 20.0,
                                                        horizontal: 16.0),
                                                // floatingLabelBehavior: FloatingLabelBehavior.always, // optional
                                              ),
                                              child: Text(
                                                _emailcontroller.text.isEmpty
                                                    ? ''
                                                    : _emailcontroller.text,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 14,
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            )),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Center(
                                        child: SizedBox(
                                            width: 0.7 * w,
                                            height: 12 +
                                                0.05 *
                                                    h, // kann auch über contentPadding gesteuert werden
                                            child: InputDecorator(
                                              isFocused: false,
                                              isEmpty:
                                                  _emailcontroller.text.isEmpty,
                                              decoration: InputDecoration(
                                                suffixIcon: const Padding(
                                                  padding: EdgeInsets.all(10.0),
                                                  child: Icon(Icons.mail),
                                                ),
                                                // WICHTIG: kein labelText, wenn "label" (Widget) verwendet wird
                                                label: Consumer<UserStore>(
                                                  builder:
                                                      (context, value, _) =>
                                                          Text(
                                                    '   ${value.mail}',
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 10,
                                                      fontFamily: 'Montserrat',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          32.0),
                                                  borderSide: const BorderSide(
                                                      color: Colors.black,
                                                      width: 1.3),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 20.0,
                                                        horizontal: 16.0),
                                                // floatingLabelBehavior: FloatingLabelBehavior.always, // optional
                                              ),
                                              child: Text(
                                                _emailcontroller.text.isEmpty
                                                    ? ''
                                                    : _emailcontroller.text,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 14,
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            )),
                                      ),
                                    ),
                                    Center(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Container(
                                          width: w * 0.7,
                                          height: 12 + h * 0.05,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFFD9D9D9),
                                            ),
                                            onPressed: () {},
                                            child: const Text(
                                              'AGB',
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
                                      ),
                                    ),
                                    Center(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: Container(
                                          width: w * 0.7,
                                          height: 12 + h * 0.05,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFFD9D9D9),
                                            ),
                                            onPressed: () {},
                                            child: const Text(
                                              'DSGVO',
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
                                      ),
                                    ),
                                    Center(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: Container(
                                          width: w * 0.7,
                                          height: 12 + h * 0.05,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFFD9D9D9),
                                            ),
                                            onPressed: () {
                                              deleteAccount();
                                            },
                                            child: const Text(
                                              'Löschen',
                                              style: TextStyle(
                                                color: Color.fromARGB(
                                                    255, 190, 1, 1),
                                                fontSize: 14,
                                                fontFamily: 'Montserrat',
                                                fontWeight: FontWeight.w600,
                                                height: 0,
                                              ),
                                            ),
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
                    )),
              ],
            );
          },
        ));
  }
}
