import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'splash_screen.dart'; // ─── IMPORTED: Bringing in Splash Screen! ───
import 'login_screen.dart'; // General together Register
import 'dashboard_home.dart'; // Amir's Part
import 'search_explore.dart'; // Amir's Part
import 'onboarding_screen.dart'; // Amir's Part
import 'safety_alerts_page.dart'; // Parvin's Part together with Notification
import 'area_map_page.dart'; // Parvin's Part
import 'hydration_and_wellness_screen.dart'; // Kiruban's Part
import 'community_feed_page.dart'; // Iqbal's Part (Live Social Feed Module! 📢)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SunClimate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      // ─── TOTAL FIX FOR 9:16 RECORDING STRETCH ──────────────────────────────
      // Overriding the builder at the engine level clamps ALL routing pages!
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black87, // Flat background color for browser edges
          body: Center(
            child: MediaQuery(
              // Forces the app framework to calculate text, gaps, and navigation as an exact phone size
              data: MediaQuery.of(context).copyWith(
                size: const Size(430, 932),
                padding: const EdgeInsets.only(top: 44, bottom: 34), // Simulates real phone status bars
              ),
              child: SizedBox(
                width: 430,
                height: 932,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12), // Subtle phone edge corners
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}

// ─── THE GATEKEEPER (MANAGES ONBOARDING STATE POST-SPLASH) ───
class AppGatekeeper extends StatefulWidget {
  const AppGatekeeper({super.key});

  @override
  State<AppGatekeeper> createState() => _AppGatekeeperState();
}

class _AppGatekeeperState extends State<AppGatekeeper> {
  bool _hasSeenOnboarding = false;
  bool _isLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    if (!_hasSeenOnboarding) {
      return OnboardingScreen(
        onOnboardingComplete: () => setState(() => _hasSeenOnboarding = true),
      );
    }

    if (!_isLoggedIn) {
      return LoginScreen(
        onLoginSuccess: () => setState(() => _isLoggedIn = true),
      );
    }

    return MainNavigationShell(
      onLogout: () => setState(() => _isLoggedIn = false),
    );
  }
}

// ─── THE MAIN NAVIGATION SHELL (6 TABS LOGIC) ───
class MainNavigationShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainNavigationShell({super.key, required this.onLogout});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  // Shared Coordinates tracking state (Defaults to Kota Bharu)
  double _sharedLat = 6.1254;
  double _sharedLng = 102.2386;
  String _sharedLocationName = "Kota Bharu, Kelantan";

  void _updateSharedLocation(double lat, double lng, String locationName) {
    setState(() {
      _sharedLat = lat;
      _sharedLng = lng;
      _sharedLocationName = locationName;
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      DashboardHome(
        onLogout: widget.onLogout,
        lat: _sharedLat,
        lng: _sharedLng,
        locationName: _sharedLocationName,
        onLocationBootstrapped: _updateSharedLocation,
      ),

      // Slot 1: Pravin's Area Map Page directly integrated into bottom navigation
      const AreaMapPage(),

      SearchExploreScreen(
        currentLat: _sharedLat,
        currentLng: _sharedLng,
        locationHeaderName: _sharedLocationName,
        onLocationChanged: _updateSharedLocation,
      ),

      // Iqbal's Section: Swapped out placeholder for live Firestore social feed stream!
      const CommunityFeedPage(),

      // Kiruban's Section (Fully integrated live dashboard widget)
      const HydrationAndWellnessScreen(),

      // Pravin's Section
      SafetyAlertsPage(
        onSeeAllReports: () {
          setState(() => _selectedIndex = 3);
        },
      ),
    ];

    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Social'),
          BottomNavigationBarItem(icon: Icon(Icons.local_drink), label: 'Reminder'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Safety'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange.shade800,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}