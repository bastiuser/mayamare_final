import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_wead/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'package:provider/provider.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:conversion/conversion.dart';


Future<Map<String, dynamic>> post(String sub,String bodys) async {
  final prefs = await SharedPreferences.getInstance();
  String cook=prefs.getString('cookie')??"";
  final response = await http.post(
    Uri.parse('http://185.164.4.177/app/$sub'),
    // Send authorization headers to the backend.
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Cookie': cook,
    },
    body: bodys,
  );
  return jsonDecode(response.body) as Map<String, dynamic>;
}
