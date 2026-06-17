import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_profile_page.dart';

class DashboardHome extends StatefulWidget {
  final VoidCallback onLogout;
  final double lat;
  final double lng;
  final String locationName;
  final Function(double, double, String) onLocationBootstrapped;

  const DashboardHome({
    super.key,
    required this.onLogout,
    required this.lat,
    required this.lng,
    required this.locationName,
    required this.onLocationBootstrapped,
  });

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  bool _isLoading = true;
  String _temp = "--°C";
  String _realFeel = "RealFeel: --°C";
  String _uvIndex = "UV Index: --";
  String _humidity = "--%";
  String _windSpeed = "-- km/h";
  String _rainChance = "--%";
  String _greetingText = "Good Day";

  @override
  void initState() {
    super.initState();
    _setDynamicGreeting();
    _initiateLocationAndWeather();
  }

  @override
  void didUpdateWidget(covariant DashboardHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      _fetchLiveWeatherData();
    }
  }

  void _setDynamicGreeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) {
      _greetingText = "Good Morning";
    } else if (hour < 17) {
      _greetingText = "Good Afternoon";
    } else {
      _greetingText = "Good Evening";
    }
  }

  Future<void> _initiateLocationAndWeather() async {
    if (widget.lat != 6.1254) {
      _fetchLiveWeatherData();
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fetchLiveWeatherData();
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _fetchLiveWeatherData();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _fetchLiveWeatherData();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low)
      ).timeout(const Duration(seconds: 4));

      String discoveredCity = "My Location";
      if ((position.latitude - 6.1254).abs() < 0.1) {
        discoveredCity = "Kota Bharu, Kelantan";
      }

      if (mounted) {
        widget.onLocationBootstrapped(position.latitude, position.longitude, discoveredCity);
      }
    } catch (e) {
      debugPrint("Location service skipped or timed out: $e");
      _fetchLiveWeatherData();
    }
  }

  Future<void> _fetchLiveWeatherData() async {
    final String openMeteoUrl =
        "https://api.open-meteo.com/v1/forecast?latitude=${widget.lat}&longitude=${widget.lng}&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,wind_speed_10m,uv_index&timezone=auto";

    try {
      final response = await http.get(Uri.parse(openMeteoUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];

        double tempC = (current['temperature_2m'] ?? 0.0).toDouble();
        double feelsLikeC = (current['apparent_temperature'] ?? 0.0).toDouble();
        double uv = (current['uv_index'] ?? 0.0).toDouble();
        int humidityVal = (current['relative_humidity_2m'] ?? 0).toInt();
        double windKmh = (current['wind_speed_10m'] ?? 0.0).toDouble();
        int chanceOfRain = (current['precipitation_probability'] ?? 0).toInt();

        if (mounted) {
          setState(() {
            _temp = "${tempC.toStringAsFixed(0)}°C";
            _realFeel = "RealFeel: ${feelsLikeC.toStringAsFixed(0)}°C";
            _uvIndex = "UV Index: ${uv.toStringAsFixed(0)} (${_getUVScale(uv)})";
            _humidity = "$humidityVal%";
            _windSpeed = "${windKmh.toStringAsFixed(0)} km/h";
            _rainChance = "$chanceOfRain%";
            _isLoading = false;
          });
        }
      } else {
        _handleFetchError();
      }
    } catch (e) {
      _handleFetchError();
    }
  }

  String _getUVScale(double uv) {
    if (uv <= 2) return "Low";
    if (uv <= 5) return "Moderate";
    if (uv <= 7) return "High";
    if (uv <= 10) return "Very High";
    return "Extreme";
  }

  void _handleFetchError() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update live climate diagnostics from open weather servers.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    String shortName = "User";

    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      shortName = user.displayName!.split(' ').first;
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade400, Colors.red.shade700],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$_greetingText, $shortName!",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.locationName,
                            style: const TextStyle(color: Colors.white70, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle, color: Colors.white, size: 32),
                      tooltip: 'View Profile',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfilePage(onLogout: widget.onLogout),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),

              Container(
                height: 240,
                width: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5
                    )
                  ],
                  border: Border.all(color: Colors.white30, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        _temp,
                        style: const TextStyle(
                            fontSize: 62,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1
                        )
                    ),
                    Text(
                        _realFeel,
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      backgroundColor: Colors.yellow.shade400,
                      side: BorderSide.none,
                      label: Text(
                          _uvIndex,
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13
                          )
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StatWidget(icon: Icons.water_drop, label: _humidity, sub: "Humidity"),
                      const VerticalDivider(color: Colors.white30, thickness: 1),
                      StatWidget(icon: Icons.air, label: _windSpeed, sub: "Wind"),
                      const VerticalDivider(color: Colors.white30, thickness: 1),
                      StatWidget(icon: Icons.cloud, label: _rainChance, sub: "Rain Chance"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── RE-ADDED THE MISSING STAT WIDGET DEFINITION HERE ───
class StatWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const StatWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.sub
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
        ),
        Text(
            sub,
            style: const TextStyle(color: Colors.white60, fontSize: 12)
        ),
      ],
    );
  }
}