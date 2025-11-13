// social_auth_sheet.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show HandshakeException, HttpException, Platform, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// UI-Buttons (offizielles Branding)
import 'package:sign_in_button/sign_in_button.dart';
import 'userdialog.dart';
// Deine bestehenden SDKs:
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialAuthSheet extends StatefulWidget {
  const SocialAuthSheet({super.key});

  @override
  State<SocialAuthSheet> createState() => _SocialAuthSheetState();
}

class _SocialAuthSheetState extends State<SocialAuthSheet> {
  // --- Deine vorhandene Konfiguration ---
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId:
        '86165855541-luj5bjeikj99obs2cfliriaf8j2i3b96.apps.googleusercontent.com',
  );
  static const String _apiBase = 'https://waterslide.works/app';

  bool get _isApplePlatform => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  bool _busy = false;
  void _setBusy(bool v) => setState(() => _busy = v);
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

  Future<void> _sendTokenToBackend(String? idToken, String platform) async {
    final uri = Uri.parse('$_apiBase/loginvia${platform.toLowerCase()}');
    try {
      final resp = await http
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{'token': idToken}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> json = jsonDecode(resp.body);
      final success = json['success'];
      final prefs = await SharedPreferences.getInstance();

      if (!success) {
        _showErrorSnack(
          '$platform-Login fehlgeschlagen',
        );
      }
      final hasUser = json['hasUser'];
      final cookie = resp.headers['set-cookie'];

      if (cookie == null) {
        _showErrorSnack(
          '$platform-Login fehlgeschlagen',
        );
        return;
      }
      if (!hasUser) {
        await showUsernameDialog(context, cookie: cookie);
      }
      final email = json['mail'];
      final user = json['username'];
      print(email);
      await prefs.setString('cookie', cookie);
      if (email != null) await prefs.setString('mail', email);
      if (mounted) {
        Provider.of<UserStore>(context, listen: false).setCook(cookie ?? '');
        if (email != null) {
          Provider.of<UserStore>(context, listen: false).changeMail(email);
        }
        if (user != null) {
          Provider.of<UserStore>(context, listen: false).changeName(user);
        }
        if (email != null) {
          context.go('/navigationscreen'); // Erfolg → Dialog schließen
        }
      }
    } on SocketException {
      // z. B. Flugmodus, WLAN/Mobilfunk weg, DNS nicht erreichbar
      _showErrorSnack(
        'Keine Internetverbindung. Bitte prüfe WLAN/Mobilfunk und versuche es erneut.',
      );
    } on TimeoutException {
      _showErrorSnack(
        'Zeitüberschreitung bei der Verbindung. Der Server ist gerade nicht erreichbar.',
      );
    } on HandshakeException {
      // SSL/TLS-Problem (z. B. falsches Zertifikat, Uhrzeit am Gerät falsch)
      _showErrorSnack(
        'Sichere Verbindung fehlgeschlagen (TLS/SSL). Bitte später erneut versuchen.',
      );
    } on HttpException catch (e) {
      _showErrorSnack('HTTP-Fehler: ${e.message}');
    } catch (e) {
      // generischer Fallback – zeigt die eigentliche Ursache mit an
      _showErrorSnack('Unerwarteter Fehler beim Login: $e');
    }
  }

  // --- Login-Methoden (aus deinem Code übernommen) ---
  Future<void> _loginWithGoogle() async {
    try {
      _setBusy(true);
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // abgebrochen
      final googleAuth = await googleUser.authentication;
      debugPrint('Google Access Token: ${googleAuth.accessToken}');
      debugPrint('Google ID Token:     ${googleAuth.idToken}');
      await _sendTokenToBackend(googleAuth.idToken, "Google");

      if (mounted) Navigator.pop(context, 'google');
      // -> Tokens sicher ans Backend senden
    } catch (e) {
      debugPrint('Google Sign-In Fehler: $e');
      _snack('Google-Anmeldung fehlgeschlagen');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _loginWithFacebook() async {
    try {
      _setBusy(true);
      final result = await FacebookAuth.instance.login();
      switch (result.status) {
        case LoginStatus.success:
          final accessToken = result.accessToken!;
          debugPrint('Facebook Access Token: ${accessToken.token}');
          debugPrint('Facebook User ID:      ${accessToken.userId}');
          await _sendTokenToBackend(accessToken.token, "Facebook");

          if (mounted) Navigator.pop(context, 'facebook');
          break;
        case LoginStatus.cancelled:
          break;
        case LoginStatus.failed:
          _snack(result.message ?? 'Facebook Login fehlgeschlagen');
          break;
        default:
          _snack('Unbekannter Facebook-Status: ${result.status}');
      }
    } catch (e) {
      debugPrint('Facebook Login Exception: $e');
      _snack('Facebook-Anmeldung fehlgeschlagen');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _loginWithApple() async {
    try {
      _setBusy(true);
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      debugPrint('Apple userIdentifier:   ${credential.userIdentifier}');
      debugPrint('Apple authorizationCode:${credential.authorizationCode}');
      debugPrint('Apple identityToken:    ${credential.identityToken}');
      await _sendTokenToBackend(credential.identityToken, "Apple");

      if (mounted) Navigator.pop(context, 'apple');
      // -> Code/Token ans Backend
    } catch (e) {
      debugPrint('Apple Sign-In Fehler: $e');
      _snack('Apple-Anmeldung fehlgeschlagen');
    } finally {
      _setBusy(false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 24,
              color: Colors.black26,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab-Handle
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),

            Text(
              'Weiter mit',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),

            // Google
            SignInButton(
              Buttons.google,
              text: 'Weiter mit Google',
              onPressed: _loginWithGoogle,
            ),
            const SizedBox(height: 12),

            // Facebook
            SignInButton(
              Buttons.facebookNew,
              text: 'Weiter mit Facebook',
              onPressed: _loginWithFacebook,
            ),
            const SizedBox(height: 12),

            // Apple nur auf Apple-Plattformen
            if (_isApplePlatform) ...[
              SignInButton(
                Buttons.appleDark,
                text: 'Mit Apple anmelden',
                onPressed: _loginWithApple,
              ),
              const SizedBox(height: 12),
            ],

            // Separator
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
