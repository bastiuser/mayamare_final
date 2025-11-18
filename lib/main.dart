import 'package:flutter/material.dart';
import 'package:flutter_application_wead/NavigationScreen.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'package:flutter_application_wead/mainpage.dart';
import 'package:flutter_application_wead/signup.dart';
import 'package:flutter_application_wead/guestlogin.dart';
import 'package:flutter_application_wead/slidehistory.dart';
import 'login.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile.dart';
import 'nfcscanner.dart';
import 'package:flutter/services.dart';
import 'UserStore.dart';
import 'slidepicker.dart';
void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Stelle sicher, dass alles initialisiert ist
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String initialRoute =
      prefs.getString('initialRoute') ?? '/'; // Standardwert ist '/'
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values, // Status + Nav-Bar ganz normal
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Locks the app in portrait mode
  ]).then((_) {
    runApp(MyApp(
      initalRoute: initialRoute,
    )); // Your app's entry point
  });
}

GoRouter initgo(String initialLocation) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
          path: '/',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              //transitionDuration: const Duration(seconds: 1),
              key: state.pageKey,
              child: const LoginForm(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1.0, 0.0), // Startpunkt (von links)
                    end: Offset.zero, // Endpunkt (in die Mitte)
                  ).animate(animation),
                  child: child,
                );
              },
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: 'signup',
              pageBuilder: (context, state) {
                return CustomTransitionPage(
                  //transitionDuration: const Duration(seconds: 1),
                  key: state.pageKey,
                  child: const SignupForm(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin:
                            const Offset(1.0, 0.0), // Startpunkt (von rechts)
                        end: Offset.zero, // Endpunkt (in die Mitte)
                      ).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
            GoRoute(
              path: 'guest',
              pageBuilder: (context, state) {
                return CustomTransitionPage(
                  //transitionDuration: const Duration(seconds: 1),
                  key: state.pageKey,
                  child: const AuthDemo(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin:
                            const Offset(1.0, 0.0), // Startpunkt (von rechts)
                        end: Offset.zero, // Endpunkt (in die Mitte)
                      ).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
          ]),
      GoRoute(
        path: '/navigationscreen',
        builder: (BuildContext context, GoRouterState state) {
          return const NavigationScreen();
        },
      ),
      GoRoute(
        path: '/nfcscan',
        builder: (BuildContext context, GoRouterState state) {
          return const NFCscanner();
        },
      ),
      GoRoute(
        path: '/mainpage',
        builder: (BuildContext context, GoRouterState state) {
          return const Mainpage();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'settings',
            builder: (BuildContext context, GoRouterState state) {
              return const Profile();
            },
          ),
          GoRoute(
            path: 'videos',
            builder: (BuildContext context, GoRouterState state) {
              return const Slidepicker();
            },
          )
        ], //füge subroutes hinzu
      ),
    ],
  );
  return router;
}

class MyApp extends StatelessWidget {
  final String initalRoute;
  const MyApp({super.key, required this.initalRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserStore>(
          create: (context) => UserStore(),
          child: const LoginForm(),
        ),
        ChangeNotifierProvider<UserStore>(
          create: (context) => UserStore(),
          child: const Mainpage(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: initgo(initalRoute),
        builder: (context, child) {
          // Hier wird die MediaQuery überschrieben, um die Textskalierung und Display-Größenanpassung zu verhindern
          final mediaQueryData = MediaQuery.of(context);

          return SafeArea(
            bottom: true,
            child: MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: TextScaler.linear(
                    1.1), // Verhindert Textskalierung durch Geräteeinstellungen
                size: mediaQueryData.size, // Beibehaltung der Bildschirmgröße
                devicePixelRatio:
                    1.0, // Verhindert die Anzeigegröße-Anpassung durch Gerät
              ),
              child: child!,
            ),
          );
        },
      ),
    );
  }
}
