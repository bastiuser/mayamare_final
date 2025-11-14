import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'signup.dart';
import 'UserStore.dart';
import 'services/media_cache_service.dart';
import 'social_auth_sheet.dart';

class Login {
  final bool success;
  final String username;
  final int userId;

  const Login({
    required this.userId,
    required this.username,
    required this.success,
  });

  factory Login.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'userid': int userId,
        'success': bool success,
        'username': String username,
      } =>
        Login(
          userId: userId,
          success: success,
          username: username,
        ),
      _ => throw const FormatException('Wrong credentials payload'),
    };
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});
  @override
  LoginFormState createState() => LoginFormState();
}

class LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passController = TextEditingController();

  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _usernameFieldKey = GlobalKey<FormFieldState<String>>();
  final _passwordFieldKey = GlobalKey<FormFieldState<String>>();
  Future<Login>? _futureLogin;
  bool isMaximized = false;
  bool _isSubmitting = false;

  // === Helpers ===============================================================

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

  // === Networking ============================================================

  Future<Login> doLogin(String user, String pass) async {
    final uri = Uri.parse('https://waterslide.works/app/login');

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'username': user,
              'password': pass,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      _showErrorSnack(
          'Zeitüberschreitung beim Anmelden. Bitte später erneut versuchen.');
      rethrow;
    } on SocketException {
      _showErrorSnack('Keine Internetverbindung. Prüfe dein Netzwerk.');
      rethrow;
    } catch (e) {
      _showErrorSnack('Unerwarteter Fehler beim Anmelden.');
      rethrow;
    }

    // HTTP-Status prüfen
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _showErrorSnack(
          'Anmeldung fehlgeschlagen (HTTP ${response.statusCode}).');
      throw HttpException('HTTP ${response.statusCode}');
    }

    Map<String, dynamic> responseJson;
    try {
      responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      _showErrorSnack('Serverantwort unlesbar. Versuche es später erneut.');
      rethrow;
    }

    // API-Fehlerfall (success=false oder fehlt)
    final apiSuccess = responseJson['success'];
    if (apiSuccess is bool && apiSuccess == false) {
      final serverMsg =
          (responseJson['message'] ?? 'Anmeldung fehlgeschlagen.') as String;
      _showErrorSnack(serverMsg);
      throw StateError('API login failed: $serverMsg');
    }

    // Optional: Cookie/Mail sichern (null-sicher)
    final prefs = await SharedPreferences.getInstance();
    final cookie = response.headers['set-cookie'];
    final mail = responseJson['mail'] as String?;
    if (cookie != null) await prefs.setString('cookie', cookie);
    if (mail != null) await prefs.setString('mail', mail);

    if (mounted) {
      Provider.of<UserStore>(context, listen: false).setCook(cookie ?? '');
      if (mail != null) {
        Provider.of<UserStore>(context, listen: false).changeMail(mail);
      }
    }

    // Erfolgs-Fall parsen
    try {
      return Login.fromJson(responseJson);
    } on FormatException catch (e) {
      _showErrorSnack('Unerwartetes Antwortformat. Versuche es später erneut.');
      throw e;
    }
  }

  // === Session/State =========================================================

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(_handleFocusChange);
    _passwordFocusNode.addListener(_handleFocusChange);
    isLoggedIn();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passController.dispose();
    _usernameFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _passwordFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final anyFocused =
        _usernameFocusNode.hasFocus || _passwordFocusNode.hasFocus;
    if (isMaximized != anyFocused) {
      setState(() => isMaximized = anyFocused);
    }
  }

  void setLoggedIn(String user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', true);
    await prefs.setString('user', user);
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    await prefs.setString('lastLogin', date.toString());
  }

  void isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    var isLogged = prefs.getBool('loggedIn') ?? false;
    var date = prefs.getString('lastLogin') ?? "";
    var uid = prefs.getBool('uid') ?? false;
    var lastScanned = prefs.getString('scan') ?? "";
    print(prefs.getString('mail'));
    if (date.isNotEmpty) {
      final loginDate = DateTime.parse(date);
      final now = DateTime.now();
      final datenow = DateTime(now.year, now.month, now.day);
      final timesince = datenow.difference(loginDate);
      if (timesince.inDays > 28) {
        isLogged = false;
      }
      if (lastScanned.isNotEmpty) {
        final diff = datenow.difference(DateTime.parse(lastScanned));
        if (diff.inDays >= 1) {
          uid = false;
          prefs.setBool('uid', false);
        }
      }
    }

    final user = prefs.getString('user') ?? "";
    final cookieheader = prefs.getString('cookie') ?? "";
    final mail=prefs.getString('mail')??"";
    if (isLogged && mounted) {
      Provider.of<UserStore>(context, listen: false).changeName(user);
      Provider.of<UserStore>(context, listen: false).setCook(cookieheader);
      Provider.of<UserStore>(context, listen: false).changeMail(mail);

      if (uid) {
        Provider.of<UserStore>(context, listen: false).setNav(true);
      }
      context.go('/navigationscreen');
    }
  }

  // === UI ====================================================================

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets; // Tastaturhöhe
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final keyboardOpen = viewInsets.bottom > 0;
    final effectiveMaximized = isMaximized || keyboardOpen;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Container(
            color: const Color(0xFFEAEAEA),
            child: Column(
              children: [
                if (!effectiveMaximized)
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: h * 0.12),
                        child: Center(
                          child: SizedBox(
                            width: w * 0.7,
                            height: w * 0.4,
                            child: const Text(
                              'Willkommen\nbei Maya Mare',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 30,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: h * 0.01),
                        child: Center(
                          child: SizedBox(
                            width: 0.7 * w,
                            height: h * 0.14,
                            child: const Text(
                              'Miss dich mit anderen und finde heraus, wer die schnellste Zeit auf den Rutschen hat.',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
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
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: effectiveMaximized ? h * 0.10 : h * 0.05,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (effectiveMaximized)
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: h * 0.01),
                                    child: SizedBox(
                                      width: w * 0.7,
                                      height: w * 0.4,
                                      child: const Text(
                                        'Willkommen\nin der Therme\nThermenname',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 30,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // USERNAME / EMAIL
                              // USERNAME / EMAIL
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: w * 0.7,
                                        height: 0.07 *
                                            h, // kompakte fixe Feldhöhe wie vorher
                                        child: TextFormField(
                                          key: _usernameFieldKey,
                                          controller: _usernameController,
                                          focusNode: _usernameFocusNode,
                                          onTapOutside: (_) =>
                                              FocusScope.of(context).unfocus(),
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) =>
                                              _passwordFocusNode.requestFocus(),
                                          keyboardType: _usernameController.text
                                                  .contains('@')
                                              ? TextInputType.emailAddress
                                              : TextInputType.text,
                                          autofillHints: const [
                                            AutofillHints.username,
                                            AutofillHints.email
                                          ],
                                          validator: (value) {
                                            final v = (value ?? '').trim();
                                            if (v.isEmpty)
                                              return 'Bitte E-Mail oder Username eingeben';
                                            if (v.contains('@') &&
                                                !EmailValidator.validate(v)) {
                                              return 'Bitte gültige E-Mail-Adresse eingeben';
                                            }
                                            return null;
                                          },
                                          decoration: InputDecoration(
                                            isDense: true,
                                            // kompakte Optik
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 10.0,
                                            ),
                                            // Fehlertext intern unterdrücken (wir rendern selbst darunter)
                                            errorStyle: const TextStyle(
                                                height: 0, fontSize: 0),

                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                              borderSide: const BorderSide(
                                                  color: Colors.black,
                                                  width: 1.3),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                              borderSide: const BorderSide(
                                                  color: Colors.black,
                                                  width: 1.6),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                              borderSide: const BorderSide(
                                                  color: Colors.red,
                                                  width: 1.6),
                                            ),
                                            focusedErrorBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                              borderSide: const BorderSide(
                                                  color: Colors.red,
                                                  width: 1.8),
                                            ),
                                            labelText: '   E-Mail/Username',
                                            labelStyle: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      // Eigener (kleiner) Fehlertext nur im Error-Fall
                                      AnimatedSize(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        curve: Curves.easeOut,
                                        child: (_usernameFieldKey
                                                    .currentState?.hasError ??
                                                false)
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 6, left: 8),
                                                child: Text(
                                                  _usernameFieldKey
                                                      .currentState!.errorText!,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.red),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // PASSWORT
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Center(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: w * 0.7,
                                        height: 0.07 *
                                            h, // kompakte fixe Höhe wie vorher
                                        child: TextFormField(
                                          key: _passwordFieldKey,
                                          controller: _passController,
                                          focusNode: _passwordFocusNode,
                                          onTapOutside: (_) =>
                                              FocusScope.of(context).unfocus(),
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
                                          obscureText: true,
                                          validator: (value) {
                                            final v = (value ?? '');
                                            if (v.isEmpty)
                                              return 'Bitte Passwort eingeben';
                                            if (v.length < 6)
                                              return 'Mindestens 6 Zeichen';
                                            return null;
                                          },
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 10.0,
                                            ),
                                            errorStyle: const TextStyle(
                                                height: 0, fontSize: 0),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                              borderSide: const BorderSide(
                                                  color: Colors.black,
                                                  width: 1.3),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                              borderSide: const BorderSide(
                                                  color: Colors.black,
                                                  width: 1.6),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                              borderSide: const BorderSide(
                                                  color: Colors.red,
                                                  width: 1.6),
                                            ),
                                            focusedErrorBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32.0),
                                              borderSide: const BorderSide(
                                                  color: Colors.red,
                                                  width: 1.8),
                                            ),
                                            labelText: '   Passwort',
                                            labelStyle: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      AnimatedSize(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        curve: Curves.easeOut,
                                        child: (_passwordFieldKey
                                                    .currentState?.hasError ??
                                                false)
                                            ? const Padding(
                                                padding: EdgeInsets.only(
                                                    top: 6, left: 8),
                                                child: Text(
                                                  'Bitte Passwort eingeben (min. 6 Zeichen)',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.red),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // LOGIN-BUTTON
                              Center(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 16, bottom: 8),
                                  child: SizedBox(
                                    width: w * 0.7,
                                    height: 8 + h * 0.05,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFD9D9D9),
                                      ),
                                      onPressed: _isSubmitting
                                          ? null
                                          : () async {
                                              FocusScope.of(context).unfocus();
                                              if (!_formKey.currentState!
                                                  .validate()) {
                                                // early exit: Formfehler werden inline angezeigt
                                                return;
                                              }
                                              setState(() {
                                                _isSubmitting = true;
                                                _futureLogin = null; // reset
                                              });
                                              try {
                                                final login = await doLogin(
                                                  _usernameController.text
                                                      .trim(),
                                                  _passController.text,
                                                );
                                                if (login.success) {
                                                  if (!mounted) return;
                                                  Provider.of<UserStore>(
                                                          context,
                                                          listen: false)
                                                      .changeName(
                                                          login.username);
                                                  setLoggedIn(login.username);

                                                  final cookie =
                                                      Provider.of<UserStore>(
                                                              context,
                                                              listen: false)
                                                          .cookie;
                                                  final svc = MediaCacheService(
                                                      cookie: cookie);
                                                  // ignore: unawaited_futures
                                                  svc.syncAll();

                                                  if (!mounted) return;
                                                  context
                                                      .go('/navigationscreen');
                                                } else {
                                                  _showErrorSnack(
                                                      'Falsche Zugangsdaten.');
                                                }
                                              } catch (_) {
                                                // Fehler wurden bereits per SnackBar kommuniziert
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    _isSubmitting = false;
                                                  });
                                                }
                                              }
                                            },
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'EINLOGGEN',
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

                              // SIGNUP-LINK
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: h * 0.04),
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Noch keinen Account?',
                                          style: TextStyle(
                                              color: Color(0xFF727272),
                                              fontSize: 12,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const TextSpan(text: ' '),
                                        TextSpan(
                                          text: 'Jetzt erstellen\n',
                                          recognizer: TapGestureRecognizer()
                                            ..onTap =
                                                () => context.go('/signup'),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // GAST / SOCIAL SHEET
                              Center(
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    text: 'als Gast fortfahren',
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        final result =
                                            await showModalBottomSheet<String>(
                                          context: context,
                                          useRootNavigator: true, // <-- neu!
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.transparent,
                                          barrierColor: Colors.black54,
                                          builder: (_) =>
                                              const SocialAuthSheet(),
                                        );

                                        if (!context.mounted) return;
                                        switch (result) {
                                          case 'guest':
                                            context.go('/guest');
                                            break;
                                          case 'google':
                                          case 'facebook':
                                          case 'apple':
                                            break;
                                          default:
                                            break;
                                        }
                                      },
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),

                              // Optional: Future-Output (Debug)
                              // Center(
                              //   child: (_futureLogin == null)
                              //       ? const SizedBox.shrink()
                              //       : buildFuterLogin(),
                              // ),
                              const SizedBox(height: 16),
                            ],
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
      ),
    );
  }

  // Kannst du weiterverwenden, wenn du unten etwas anzeigen willst.
  FutureBuilder<Login> buildFuterLogin() {
    return FutureBuilder<Login>(
      future: _futureLogin,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data!.success) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              Provider.of<UserStore>(context, listen: false)
                  .changeName(snapshot.data!.username);
              setLoggedIn(snapshot.data!.username);

              final cookie =
                  Provider.of<UserStore>(context, listen: false).cookie;
              final svc = MediaCacheService(cookie: cookie);
              // ignore: unawaited_futures
              svc.syncAll();

              context.go('/navigationscreen');
            });
            return Text(snapshot.data!.username);
          }
        } else if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        return const CircularProgressIndicator();
      },
    );
  }
}
