import 'dart:core';

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



class BestenListeTop extends StatelessWidget {
  const BestenListeTop({
    super.key,
    required this.h,
    required this.w,
  });

  final double h;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Container(
        height: h * 0.39,
        
        child: Stack(children: [
          Positioned(
            
            left: w * 0.7,
            top: 30,
            height: h * 0.10,
            child: Padding(
              padding: const EdgeInsets.only(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image(
                    image:
                        AssetImage('assets/newlogo.png'),
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
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: w * 0.7,
                          child: Consumer<UserStore>(
                            builder:
                                (context, value, child) =>
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
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: w * 0.7,
                          child: Text(
                            'Bestenliste',
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
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 0.7 * w,
                        height: h * 0.14,
                        child: Text(
                          'Miss dich mit den Schnellsten und finde heraus, wer ganz oben steht',
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
      );
  }
}
