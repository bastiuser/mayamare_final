import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: AuthDemo(),
    );
  }
}

class AuthDemo extends StatefulWidget {
  const AuthDemo({super.key});
  @override
  State<AuthDemo> createState() => _AuthDemoState();
}

class _AuthDemoState extends State<AuthDemo> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId: '86165855541-luj5bjeikj99obs2cfliriaf8j2i3b96.apps.googleusercontent.com',
  );

  bool get _isApplePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<void> _loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google Sign-In abgebrochen');
        return;
      }
      final googleAuth = await googleUser.authentication;
      debugPrint('Google Access Token: ${googleAuth.accessToken}');
      debugPrint('Google ID Token:     ${googleAuth.idToken}');
      // -> An dein Backend senden (HTTPS, POST Body)
    } catch (e) {
      debugPrint('Google Sign-In Fehler: $e');
    }
  }

  Future<void> _loginWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();
      switch (result.status) {
        case LoginStatus.success:
          final accessToken = result.accessToken!;
          debugPrint('Facebook Access Token: ${accessToken.token}');
          debugPrint('Facebook User ID:      ${accessToken.userId}');
          // -> An dein Backend senden
          break;
        case LoginStatus.cancelled:
          debugPrint('Facebook Login abgebrochen');
          break;
        case LoginStatus.failed:
          debugPrint('Facebook Login Fehler: ${result.message}');
          break;
        default:
          debugPrint('Unbekannter Facebook-Status: ${result.status}');
      }
    } catch (e) {
      debugPrint('Facebook Login Exception: $e');
    }
  }

  Future<void> _loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // optional: nonce/state generieren & prüfen (empfohlen)
      );

      debugPrint('Apple userIdentifier:   ${credential.userIdentifier}');
      debugPrint('Apple authorizationCode:${credential.authorizationCode}');
      debugPrint('Apple identityToken:    ${credential.identityToken}');
      // -> authorizationCode/identityToken sicher per HTTPS an dein Backend senden
    } catch (e) {
      debugPrint('Apple Sign-In Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Social Login Demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _loginWithGoogle,
              child: const Text('Login mit Google'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loginWithFacebook,
              child: const Text('Login mit Facebook'),
            ),
            const SizedBox(height: 16),
            if (_isApplePlatform)
              SignInWithAppleButton(
                onPressed: _loginWithApple,
                // optional: style: SignInWithAppleButtonStyle.black,
              ),
          ],
        ),
      ),
    );
  }
}