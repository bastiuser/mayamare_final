import 'dart:async';
import 'dart:convert';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class Signup {
  final bool success;
  const Signup({required this.success});

  factory Signup.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'success': bool success} => Signup(success: success),
      _ => throw const FormatException('Wrong credentials'),
    };
  }

  bool getsucc() => success;
}

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});
  @override
  State<SignupForm> createState() => SignupFormState();
}

class SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passController = TextEditingController();
  final _passControllerConfirm = TextEditingController();
  final _emailController = TextEditingController();

  // Fokus-Handling
  final _usernameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _passwordConfirmFocusNode = FocusNode();
  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            success ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void doSignup(String user, String pass, String email) async {
    final response = await http.post(
      Uri.parse('https://waterslide.works/app/signup'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'username': user,
        'password': pass,
        'mail': email,
      }),
    );

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final sign = Signup.fromJson(responseJson);
    final reason = responseJson['reason'];
    if (sign.getsucc()) {
      // optional SnackBar
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text('Signup erfolgreich')));
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
    }
  }

  bool isMaximized = false;
  bool check = false;

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(_handleFocusChange);
    _emailFocusNode.addListener(_handleFocusChange);
    _passwordFocusNode.addListener(_handleFocusChange);
    _passwordConfirmFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passController.dispose();
    _passControllerConfirm.dispose();
    _emailController.dispose();
    _usernameFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _emailFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _passwordFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _passwordConfirmFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final anyFocused = _usernameFocusNode.hasFocus ||
        _emailFocusNode.hasFocus ||
        _passwordFocusNode.hasFocus ||
        _passwordConfirmFocusNode.hasFocus;

    if (isMaximized != anyFocused) {
      setState(() => isMaximized = anyFocused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets; // Tastaturhöhe
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // Wenn Tastatur offen ist, gilt der Screen als "maximized"
    final keyboardOpen = viewInsets.bottom > 0;
    final effectiveMaximized = isMaximized || keyboardOpen;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // Wir steuern die Einrückung selbst via AnimatedPadding:
        resizeToAvoidBottomInset: false,
        body: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                              height: h * 0.1,
                              child: const Text(
                                'Join the Race',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 32,
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
                                'Melde dich an, um deine Rutschzeiten zu verfolgen und dich stets neu herauszufordern.',
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
                        )
                      ],
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: effectiveMaximized ? h * 1 : h * 0.67,
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
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: w),
                        child: Padding(
                          padding: EdgeInsets.only(top: h * 0.04),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (effectiveMaximized)
                                  Center(
                                    child: SizedBox(
                                      width: w * 0.7,
                                      height: h * 0.1,
                                      child: const Text(
                                        'Join the Race',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 32,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Username
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 0.7 * w,
                                      height: 0.07 * h,
                                      child: TextFormField(
                                        controller: _usernameController,
                                        focusNode: _usernameFocusNode,
                                        onTapOutside: (_) =>
                                            FocusScope.of(context).unfocus(),
                                        decoration: InputDecoration(
                                          labelText: '   Username',
                                          labelStyle: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(32.0),
                                            borderSide: const BorderSide(
                                              color: Colors.black,
                                              width: 1.3,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                        ),
                                        validator: (v) =>
                                            (v == null || v.isEmpty)
                                                ? 'Bitte Username eingeben'
                                                : null,
                                      ),
                                    ),
                                  ),
                                ),
                                // Email
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Center(
                                    child: SizedBox(
                                      width: 0.7 * w,
                                      height: 0.07 * h,
                                      child: TextFormField(
                                        controller: _emailController,
                                        focusNode: _emailFocusNode,
                                        onTapOutside: (_) =>
                                            FocusScope.of(context).unfocus(),
                                        decoration: InputDecoration(
                                          labelText: '   E-Mail',
                                          labelStyle: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(32.0),
                                            borderSide: const BorderSide(
                                              color: Colors.black,
                                              width: 1.3,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Bitte E-Mail eingeben';
                                          } else if (!EmailValidator.validate(
                                              value)) {
                                            return 'Bitte gültige E-Mail-Adresse eingeben';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                // Passwort
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Center(
                                    child: SizedBox(
                                      width: 0.7 * w,
                                      height: 0.07 * h,
                                      child: TextFormField(
                                        controller: _passController,
                                        focusNode: _passwordFocusNode,
                                        onTapOutside: (_) =>
                                            FocusScope.of(context).unfocus(),
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText: '   Passwort',
                                          labelStyle: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(32.0),
                                            borderSide: const BorderSide(
                                              color: Colors.black,
                                              width: 1.3,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Bitte Passwort eingeben';
                                          } else if (value !=
                                              _passControllerConfirm.text) {
                                            return 'Passwörter müssen identisch sein';
                                          }
                                          if (value.length < 6)
                                            return 'Mindestens 6 Zeichen';

                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                // Passwort bestätigen
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Center(
                                    child: SizedBox(
                                      width: 0.7 * w,
                                      height: 0.07 * h,
                                      child: TextFormField(
                                        controller: _passControllerConfirm,
                                        focusNode: _passwordConfirmFocusNode,
                                        onTapOutside: (_) =>
                                            FocusScope.of(context).unfocus(),
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText: '   Passwort wiederholen',
                                          labelStyle: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(32.0),
                                            borderSide: const BorderSide(
                                              color: Colors.black,
                                              width: 1.3,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Bitte Passwort bestätigen';
                                          } else if (value !=
                                              _passController.text) {
                                            return 'Passwörter müssen identisch sein';
                                          }
                                          if (value.length < 6) {
                                            return 'Mindestens 6 Zeichen';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                // Button
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 16, bottom: 14),
                                    child: SizedBox(
                                      width: w * 0.7,
                                      height: 8 + h * 0.05,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFD9D9D9),
                                        ),
                                        onPressed: () {
                                          FocusScope.of(context)
                                              .unfocus(); // wichtig
                                          if (!check) {
                                            _showSnack(
                                              'Bitte akzeptiere zuerst die Datenschutzerklärung.',
                                              success: false,
                                            );
                                            return;
                                          }
                                          if (_formKey.currentState!
                                              .validate()) {
                                            doSignup(
                                              _usernameController.text,
                                              _passController.text,
                                              _emailController.text,
                                            );
                                          }
                                        },
                                        child: const Text(
                                          'REGISTRIEREN',
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
                                // AGB Toggle
                                Center(
                                  child: Container(
                                    color: Colors.transparent,
                                    width: 230,
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () =>
                                              setState(() => check = !check),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            width: 45,
                                            height: 8 + h * 0.03,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.rectangle,
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              border: Border.all(
                                                color: Colors.black,
                                                width: 2,
                                              ),
                                              color: check
                                                  ? const Color(0xFFD9D9D9)
                                                  : Colors.transparent,
                                            ),
                                            child: Center(
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                opacity: check ? 1.0 : 0.0,
                                                child: const Icon(
                                                  Icons.check,
                                                  size: 20,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        InkWell(
                                          onTap: () async {
                                            final url = Uri.parse(
                                                'https://waterslide.works/static/datenschutz.html');
                                            if (!await launchUrl(
                                              url,
                                              mode: LaunchMode
                                                  .externalApplication, // öffnet im Browser
                                            )) {
                                              throw Exception(
                                                  'Konnte URL nicht öffnen');
                                            }
                                          },
                                          child: const Text(
                                            'Datenschutz akzeptiert',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                              fontSize: 12,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                // Login-Link
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: h * 0.02),
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          const TextSpan(
                                            text:
                                                'Du hast bereits einen Account?',
                                            style: TextStyle(
                                              color: Color(0xFF727272),
                                              fontSize: 12,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const TextSpan(text: '  '),
                                          TextSpan(
                                            text: 'Einloggen',
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () =>
                                                  GoRouter.of(context).go('/'),
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
      ),
    );
  }
}
