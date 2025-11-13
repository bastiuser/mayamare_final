import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

class UserStore extends ChangeNotifier {
  String _name = "";
  bool _connected=false;
  int? _tag;
  String _cookie="";
  String get user => _name;
  String _mail="";
  String get mail => _mail;
  void changeName(String user) {
    _name = user;
    notifyListeners();
  }
  void changeMail(String mail) {
    _mail = mail;
    notifyListeners();
  }
  void changeTag(int? t){
    _tag=t;
    notifyListeners();
  }
  void clearAll(){
    _name="";
    _tag=0;
    notifyListeners();
  }
  void setNav(bool conn){
    _connected=conn;
  }
  void setCook(String c){
    _cookie=c;
  }
  int? get data => _tag;
  bool get landing => _connected;
  String get cookie => _cookie;

}
