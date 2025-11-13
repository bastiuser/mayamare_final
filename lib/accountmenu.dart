import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_wead/profile.dart';
import 'package:flutter_application_wead/slidepicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'package:provider/provider.dart';

class Accountmenu extends StatelessWidget {
  const Accountmenu({super.key});
  void deleteStoredData(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Provider.of<UserStore>(context, listen: false).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
        child: Consumer<UserStore>(
          builder: (context, value, child) => Stack(
            children: [
              Row(children: [
                Text(value.user),
                const Icon(Icons.manage_accounts),
              ]),
            ],
          ),
        ),
        onSelected: (value) {
          if (value == 'logout') {
            deleteStoredData(context);
            context.go('/');
          } else if (value == 'about') {
            showAboutDialog(
              context: context,
              applicationName: 'Thermesoundso App',
              applicationVersion: '1.0.0',
            );
          } else if (value == 'account') {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const Profile()));
          } 
        },
        itemBuilder: (BuildContext bc) {
          return [
            const PopupMenuItem(
              value: 'account',
              child: Row(children: [
                Icon(Icons.settings),
                Text(" Settings"),
              ]),
            ),
            const PopupMenuItem(
              value: 'about',
              child: Row(children: [
                Icon(Icons.info),
                Text(" About"),
              ]),
            ),
            const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout),
                  Text(" Logout"),
                ])),
          ];
        });
  }
}
