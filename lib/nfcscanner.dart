import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'UserStore.dart';
import 'accountmenu.dart';
import 'commonfunctions.dart';
import 'signup.dart';

class Test {
  final bool success;

  const Test({
    required this.success,
  });

  factory Test.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'success': bool success,
      } =>
        Test(
          success: success,
        ),
      _ => throw const FormatException('Wrong credentials'),
    };
  }

  bool getsucc() {
    return success;
  }
}

class NFCscanner extends StatefulWidget {
  const NFCscanner({super.key});

  @override
  _NFCscannerState createState() => _NFCscannerState();
}

class _NFCscannerState extends State<NFCscanner> {
  bool isPending = false;
  MobileScannerController? _qrController;
  bool _qrLocked = false; // verhindert Doppel-Treffer

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

  Future<bool> setUID(int uid) async {
    try {
      final cookie = Provider.of<UserStore>(context, listen: false).cookie;
      final response = await http
          .post(
            Uri.parse('https://waterslide.works/app/uuid'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Cookie': cookie,
            },
            body: jsonEncode(<String, dynamic>{'uuid': uid}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showSnack(
            'Verbindungsfehler (${response.statusCode}). Bitte später erneut versuchen.');
        return false;
      }

      late Map<String, dynamic> responseJson;
      try {
        responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      } on FormatException {
        _showSnack(
            'Unerwartete Server-Antwort. Bitte später nochmals versuchen.');
        return false;
      }

      final test = Test.fromJson(responseJson);
      if (test.getsucc()) {
        _showSnack('Armband erfolgreich verbunden.', success: true);
        return true;
      } else {
        _showSnack('Armband konnte nicht verbunden werden.');
        return false;
      }
    } on SocketException {
      _showSnack('Keine Internetverbindung. Bitte überprüfe deine Verbindung.');
    } on TimeoutException {
      _showSnack('Zeitüberschreitung. Server nicht erreichbar.');
    } catch (e) {
      _showSnack('Unerwarteter Fehler: $e');
    }
    return false;
  }

  Future<bool> delUID(int uid) async {
    try {
      final cookie = Provider.of<UserStore>(context, listen: false).cookie;
      final response = await http
          .delete(
            Uri.parse('https://waterslide.works/app/uuid'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Cookie': cookie,
            },
            body: jsonEncode(<String, dynamic>{'uuid': uid}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showSnack('Trennen fehlgeschlagen (${response.statusCode}).');
        return false;
      }

      late Map<String, dynamic> responseJson;
      try {
        responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      } on FormatException {
        _showSnack('Unerwartete Server-Antwort beim Trennen.');
        return false;
      }

      final test = Test.fromJson(responseJson);
      if (test.getsucc()) {
        _showSnack('Verbindung erfolgreich getrennt.', success: true);
        return true;
      } else {
        _showSnack('Verbindung konnte nicht getrennt werden.');
        return false;
      }
    } on SocketException {
      _showSnack('Keine Internetverbindung. Trennen nicht möglich.');
    } on TimeoutException {
      _showSnack('Zeitüberschreitung beim Trennen.');
    } catch (e) {
      _showSnack('Unerwarteter Fehler: $e');
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      _qrController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }
  }

  @override
  void dispose() {
    _qrController?.dispose();
    super.dispose();
  }

  Future<bool> deleteTag() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('uidInt') ?? 0;
    final ok = await delUID(id);
    if (!ok) return false;
    await prefs.setBool('loggedIn', true);
    await prefs.setBool('uid', false);
    return true;
  }

  Future<void> _onQrDetected(String raw) async {
    if (_qrLocked) return;
    _qrLocked = true;
    setState(() => isPending = true);

    try {
      int? uid;

      // 1) Dezimal?
      final dec = int.tryParse(raw.trim());
      if (dec != null) {
        uid = dec;
      } else {
        // 2) Hex (0x..., Groß/Klein egal, Trennzeichen egal)
        final hex =
            raw.trim().toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
        if (hex.isNotEmpty) {
          uid = int.parse(hex, radix: 16);
        }
      }

      if (uid == null) {
        _showSnack(
            'QR-Code konnte nicht gelesen werden. Bitte erneut scannen.');
        _qrLocked = false;
        setState(() => isPending = false);
        return;
      }

      Future<void> _finalizeConnection(int uid) async {
        final prefs = await SharedPreferences.getInstance();

        final success = await setUID(uid);
        if (!success) {
          setState(() => isPending = false);
          if (Platform.isIOS) {
            _qrLocked = false;
            await _qrController?.start();
          }
          return;
        }

        await prefs.setInt('uidInt', uid);
        await prefs.setBool('uid', true);
        final now = DateTime.now();
        final date = DateTime(now.year, now.month, now.day);
        await prefs.setString('scan', date.toString());

        if (mounted) {
          Provider.of<UserStore>(context, listen: false).setNav(true);
        }
        setState(() => isPending = false);
      }

      await _qrController?.stop();
      await _finalizeConnection(uid);
    } catch (e) {
      _showSnack('Fehler beim Verarbeiten des QR-Codes: $e');
      _qrLocked = false;
      setState(() => isPending = false);
      await _qrController?.start();
    }
  }

  /// UID als Hex-String aus einem Android-NFC-Tag holen
  String? _extractUidHex(NfcTag tag) {
    final androidTag = NfcTagAndroid.from(tag);
    if (androidTag == null) return null;

    final bytes = androidTag.id;
    if (bytes.isEmpty) return null;

    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toUpperCase();
  }

  // Android: NFC-Scanner
  Future<void> scanTag(BuildContext context) async {
    setState(() {
      isPending = true;
    });

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      onDiscovered: (NfcTag tag) async {
        try {
          final prefs = await SharedPreferences.getInstance();

          final uidHex = _extractUidHex(tag);
          if (uidHex == null) {
            _showSnack('NFC-Tag konnte nicht gelesen werden.');
            await NfcManager.instance.stopSession();
            if (mounted) setState(() => isPending = false);
            return;
          }

          final uid = int.parse(uidHex, radix: 16);

          Provider.of<UserStore>(context, listen: false).changeTag(uid);
          final success = await setUID(uid);
          if (!success) {
            await NfcManager.instance.stopSession();
            if (mounted) setState(() => isPending = false);
            return;
          }

          await prefs.setInt('uidInt', uid);
          await prefs.setBool('uid', true);
          final now = DateTime.now();
          final date = DateTime(now.year, now.month, now.day);
          await prefs.setString('scan', date.toString());

          if (context.mounted) {
            Provider.of<UserStore>(context, listen: false).setNav(true);
          }

          await NfcManager.instance.stopSession();

          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            setState(() {
              isPending = false;
            });
          }
        } catch (e) {
          _showSnack('Fehler beim Lesen des NFC-Tags: $e');
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (mounted) {
            setState(() {
              isPending = false;
            });
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userStore = Provider.of<UserStore>(context, listen: false);
    final switcher = userStore.landing;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFFEAEAEA),
            actions: const [Accountmenu()],
          ),
          body: Container(
            color: const Color(0xFFEAEAEA),
            child: Column(
              children: [
                Container(
                  height: h * 0.28,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: h * 0.04),
                            child: Center(
                              child: Container(
                                width: w * 0.7,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: w * 0.7,
                                      child: Consumer<UserStore>(
                                        builder: (context, value, child) =>
                                            Text(
                                          'Hallo, ${value.user} !',
                                          style: const TextStyle(
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
                            padding: EdgeInsets.only(top: h * 0.01),
                            child: Center(
                              child: Container(
                                width: w * 0.7,
                                height: h * 0.1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: w * 0.7,
                                      child: const Text(
                                        'Armband',
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
                                      child: const Text(
                                        'Verbinde dein Armband um alle Funktionen der App zu nutzen',
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: h * 0.59,
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
                    child: Padding(
                      padding: EdgeInsets.only(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 0),
                                child: isPending
                                    ? Padding(
                                      padding: EdgeInsets.only(
                                                    top: h * 0.1),
                                      child: ThreeDotsLoader(),
                                    )
                                    : !switcher
                                        ? (Platform.isIOS
                                            // ---------- iOS: QR-SCANNER ----------
                                            ? Padding(
                                                padding: EdgeInsets.only(
                                                    top: h * 0.02),
                                                child: Column(
                                                  key: const ValueKey('ios-qr'),
                                                  children: [
                                                    Container(
                                                      width: w * 0.55,
                                                      height: w * 0.55,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(24),
                                                        color: const Color(
                                                            0xFF111111),
                                                      ),
                                                      clipBehavior:
                                                          Clip.antiAlias,
                                                      child: Stack(
                                                        fit: StackFit.expand,
                                                        children: [
                                                          MobileScanner(
                                                            controller:
                                                                _qrController,
                                                            onDetect:
                                                                (capture) async {
                                                              if (isPending) {
                                                                return;
                                                              }
                                                              final codes =
                                                                  capture
                                                                      .barcodes;
                                                              if (codes
                                                                  .isEmpty) {
                                                                return;
                                                              }
                                                              final raw = codes
                                                                  .first
                                                                  .rawValue;
                                                              if (raw == null ||
                                                                  raw.isEmpty) {
                                                                return;
                                                              }
                                                              await _onQrDetected(
                                                                  raw);
                                                            },
                                                          ),
                                                          Align(
                                                            alignment: Alignment
                                                                .topCenter,
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(12),
                                                              child: Text(
                                                                'Richte die Kamera auf den QR-Code\ndes Tablets',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white
                                                                      .withOpacity(
                                                                          0.9),
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        IconButton(
                                                          tooltip:
                                                              'Kamera wechseln',
                                                          onPressed: () async {
                                                            await _qrController
                                                                ?.switchCamera();
                                                          },
                                                          icon: const Icon(Icons
                                                              .cameraswitch),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Text(
                                                      'Der QR-Code wird automatisch erkannt und verbunden.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color:
                                                            Color(0xFF727272),
                                                        fontSize: 12,
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (isPending) ...[
                                                      const SizedBox(
                                                          height: 16),
                                                      ThreeDotsLoader(),
                                                    ],
                                                  ],
                                                ),
                                              )
                                            // ---------- Android: NFC ----------
                                            : Padding(
                                                padding: EdgeInsets.only(
                                                    top: h * 0.1),
                                                child: Column(
                                                  key: const ValueKey(
                                                      'android-nfc'),
                                                  children: [
                                                    SizedBox(
                                                      width: w * 0.7,
                                                      height: 8 + h * 0.05,
                                                      child: ElevatedButton(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                  0xFFD9D9D9),
                                                        ),
                                                        onPressed: () =>
                                                            scanTag(context),
                                                        child: const Text(
                                                          'JETZT VERBINDEN',
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 14,
                                                            fontFamily:
                                                                'Montserrat',
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          top: h * 0.02),
                                                      child: const Text(
                                                        'Halte dein Armband in die Nähe\ndeines Handys und drücke auf\n“JETZT VERBINDEN”',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFF727272),
                                                          fontSize: 12,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isPending) ...[
                                                      const SizedBox(
                                                          height: 16),
                                                      ThreeDotsLoader(),
                                                    ],
                                                  ],
                                                ),
                                              ))
                                        : Center(
                                            child: Padding(
                                              padding:
                                                  EdgeInsets.only(top: h * 0.1),
                                              child: AnimatedSwitcher(
                                                duration: const Duration(
                                                    milliseconds: 500),
                                                child: switcher
                                                    ? Column(
                                                        key: const ValueKey(2),
                                                        children: [
                                                          SvgPicture.asset(
                                                            'assets/icon_watch.svg',
                                                            semanticsLabel:
                                                                'A red up arrow',
                                                          ),
                                                          Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                              top: h * 0.04,
                                                              bottom: h * 0.02,
                                                            ),
                                                            child: const Text(
                                                              'Erfolgreich verbunden!',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                height: 0.08,
                                                              ),
                                                            ),
                                                          ),
                                                          GestureDetector(
                                                            onTap: () async {
                                                              if (await deleteTag()) {
                                                                setState(() {
                                                                  Provider.of<UserStore>(
                                                                          context,
                                                                          listen:
                                                                              false)
                                                                      .setNav(
                                                                          false);
                                                                });
                                                                if (Platform
                                                                    .isIOS) {
                                                                  _qrLocked =
                                                                      false;
                                                                  await _qrController
                                                                      ?.start();
                                                                }
                                                              }
                                                            },
                                                            child: const Text(
                                                              'Verbindung trennen',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                decoration:
                                                                    TextDecoration
                                                                        .underline,
                                                                height: 0,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : Container(),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class ThreeDotsLoader extends StatefulWidget {
  @override
  _ThreeDotsLoaderState createState() => _ThreeDotsLoaderState();
}

class _ThreeDotsLoaderState extends State<ThreeDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(40),
      ),
      child: SizedBox(
        width: 90,
        height: 50,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                return Opacity(
                  opacity: _animation.value > (index * 0.3)
                      ? 1
                      : _animation.value / (index * 0.3 + 1),
                  child: const CircleAvatar(
                    radius: 4,
                    backgroundColor: Colors.black,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
