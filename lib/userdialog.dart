import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Öffnet einen Dialog, mit dem der User einen Username setzen kann.
/// Gibt bei Erfolg den finalen Username zurück, sonst `null`.
Future<String?> showUsernameDialog(
  BuildContext context, {
  required String cookie,
}) {
  return showDialog<String>(
    context: context,
    useRootNavigator: true, // <-- wichtig!
    barrierDismissible:
        false, // während Eingabe/Loading nicht versehentlich schließen
    builder: (_) => _UsernameDialog(
      cookie: cookie,
    ),
  );
}

class _UsernameDialog extends StatefulWidget {
  final String cookie;
  const _UsernameDialog({
    required this.cookie,
  });

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  bool _submitting = false;
  bool _privacyAccepted = false;

  // Inline-Fehler (Server/Netzwerk). Wird beim Tippen ausgeblendet.
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (_inlineError != null) {
        setState(() => _inlineError = null);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _validator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Bitte einen Benutzernamen eingeben.';
    if (v.length < 3) return 'Mindestens 3 Zeichen.';
    if (v.length > 16) return 'Maximal 16 Zeichen.';
    final ok = RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(v);
    if (!ok) return 'Nur Buchstaben, Zahlen, „_“ und „.“ erlaubt.';
    return null;
  }

  Future<void> _submit() async {
    // Validator-Fehler anzeigen
    if (!_privacyAccepted) {
      setState(() {
        _inlineError = 'Bitte akzeptiere zuerst die Datenschutzerklärung.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final username = _ctrl.text.trim();
    setState(() {
      _submitting = true;
      _inlineError = null;
    });

    try {
      final uri = Uri.parse('https://waterslide.works/app/setguestusername');
      final resp = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Cookie': widget.cookie,
            },
            body: jsonEncode({'username': username}),
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        String serverMsg = 'Fehler (${resp.statusCode})';
        try {
          final json = jsonDecode(resp.body);
          final m = (json is Map) ? json['message'] : null;
          if (m is String && m.isNotEmpty) serverMsg = m;
        } catch (_) {}
        setState(() => _inlineError = serverMsg);
        return;
      }
      String email = '';
      // Erwartetes Schema: { success: true/false, message?: string, username?: string }
      try {
        final json = jsonDecode(resp.body);
        final success = (json is Map) ? json['success'] == true : false;
        if (!success) {
          final msg = (json is Map && json['message'] is String)
              ? json['message'] as String
              : 'Unbekannter Fehler';
          setState(() => _inlineError = msg);
          return;
        }
        final userexists = json['userexits'];
        if (userexists) {
          setState(() => _inlineError =
              "Username existiert, bitte einen anderen verwenden");
          return;
        }
        final String? mail = json['mail'];
        final prefs = await SharedPreferences.getInstance();
        if (mail != null) {
          email = mail;
        }
        await prefs.setString('mail', email);

        await prefs.setString('user', username);
        await prefs.setString('cookie', widget.cookie);
      } catch (_) {
        // Falls kein/anderes JSON zurückkommt, aber 2xx: wir akzeptieren es
      }

      if (!mounted) return;
      Provider.of<UserStore>(context, listen: false).changeMail(email);
      Provider.of<UserStore>(context, listen: false).setCook(widget.cookie);
      Provider.of<UserStore>(context, listen: false).changeName(username);
      Navigator.pop(context);
    } on SocketException {
      setState(() => _inlineError = 'Keine Internetverbindung.');
    } on TimeoutException {
      setState(() => _inlineError = 'Zeitüberschreitung. Bitte später erneut.');
    } on HandshakeException {
      setState(() => _inlineError = 'Sichere Verbindung fehlgeschlagen (TLS).');
    } catch (e) {
      setState(() => _inlineError = 'Unerwarteter Fehler: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.person, size: 26),
                  const SizedBox(width: 10),
                  const Text(
                    'Benutzernamen festlegen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Wähle einen eindeutigen Namen (3–20 Zeichen).',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 16),

              // Form
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _ctrl,
                  autofocus: true,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.done,
                  maxLength: 20,
                  decoration: InputDecoration(
                    hintText: '',
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF3F3F3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  validator: _validator,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),

              // Inline-Fehler (Server/Netzwerk)
              if (_inlineError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: Color(0xFFB00020)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: const TextStyle(
                          color: Color(0xFFB00020),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Bestätigen',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _privacyAccepted,
                    onChanged: _submitting
                        ? null
                        : (v) {
                            setState(() {
                              _privacyAccepted = v ?? false;
                              _inlineError = null;
                            });
                          },
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final uri = Uri.parse(
                            'https://waterslide.works/static/datenschutz.html');
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: const Text(
                        'Ich akzeptiere die Datenschutzerklärung',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
