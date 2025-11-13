import 'dart:async';
import 'dart:convert';
import 'package:flutter_application_wead/UserStore.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_wead/mainpage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class Slideentry {
  double? speed;
  String? user;
  double? time;
  int? points;
  String? text;
  Slideentry({this.time, this.points, this.speed, this.user, this.text});

  Slideentry.fromJson(Map<String, dynamic> json) {
    points = json['points'];

    if (json['speed'] is int) {
      int speedint = json['speed'];
      speed = speedint.toDouble();
    } else {
      speed = json['speed'];
    }

    if (json['time'] is int) {
      int times = json['time'];
      time = times.toDouble();
    } else {
      time = json['time'];
    }
    user = json['username'];
    text = json['text'];
  }
}
