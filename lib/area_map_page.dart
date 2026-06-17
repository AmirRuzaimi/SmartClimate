import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

class AreaMapPage extends StatefulWidget {
  const AreaMapPage({super.key});

  @override
  State<AreaMapPage> createState() => _AreaMapPageState();
}

class _AreaMapPageState extends State<AreaMapPage> {
  bool _isOfficialData = true;
  final MapController _mapController = MapController();

  // 1. Real geographic coordinates around your university region (UMK / Kelantan area as a baseline)
  // You can adjust these Lat/Lng numbers to match any city neighborhood you want!
  final List<Map<String, dynamic>> _pins = [
    {'type': 'official', 'temp': 36, 'point': const LatLng(6.1254, 102.2850), 'color': Colors.red},
    {'type': 'official', 'temp': 34, 'point': const LatLng(6.1310, 102.2920), 'color': Colors.orange},
    {'type': 'official', 'temp': 34, 'point': const LatLng(6.1180, 102.2790), 'color': Colors.orange},
    {'type': 'user', 'temp': 32, 'point': const LatLng(6.1280, 102.3010), 'color': Colors.amber},
    {'type': 'official', 'temp': 31, 'point': const LatLng(6.1150, 102.2950), 'color': Colors.green},
  ];

  // 2. Automatically center the map viewport around the hottest active pin location
  void _resetCameraToHottestPin() {
    // Filter out visible pins based on our current toggle selection
    final visiblePins = _pins.where((pin) =>
    (_isOfficialData && pin['type'] == 'official') || (!_isOfficialData && pin['type'] == 'user')
    ).toList();

    if (visiblePins.isNotEmpty) {
      // Sort visible pins descending to find the maximum temperature element
      visiblePins.sort((a, b) => b['temp'].compareTo(a['temp']));
      final hottestPoint = visiblePins.first['point'] as LatLng;

      _mapController.move(hottestPoint, 14.5); // Move camera to location with a clean zoom factor
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter and sort pins from High Temperature to Low Temperature
    // This allows us to handle map indexing layers elegantly if elements overlap
    final filteredPins = _pins.where((pin) {
      return (_isOfficialData && pin['type'] == 'official') ||
          (!_isOfficialData && pin['type'] == 'user');
    }).toList();

    // Sorting high-to-low ensures hottest locations are rendered or brought forward if needed
    filteredPins.sort((a, b) => b['temp'].compareTo(a['temp']));

    return Scaffold(
      backgroundColor: const Color(0xFF121421),
      body: Stack(
        children: [
          // ─── REAL OPENSTREETMAP ENGINE LAYER (NO API KEY REQUIRED) ───
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(6.1254, 102.2850), // Center coordinates
                initialZoom: 14.0,
                minZoom: 3.0,
                maxZoom: 18.0,
              ),
              children: [
                // Free Tile Server Provider
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.suncare.app',
                ),

                // Active Custom Temperature Hotspot Markers Layer
                MarkerLayer(
                  markers: filteredPins.map((pin) {
                    return Marker(
                      point: pin['point'],
                      width: 50,
                      height: 60,
                      alignment: Alignment.topCenter, // Anchors the bottom pointer of teardrop to the map coord
                      child: _buildHeatPin(pin['temp'].toString(), pin['color']),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // ─── UI CONTROLS OVERLAYS ───

          // Header Title
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'SURROUNDING AREAS MAP',
                style: TextStyle(
                  color: Colors.black, // Darkened font text to stand out nicely over crisp light OSM map tiles
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.white, offset: Offset(0, 1), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),

          // Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 55,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search for a neighborhood...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black38),
                  icon: Icon(Icons.search, color: Colors.black45),
                ),
              ),
            ),
          ),

          // Focus Action Button (Brings users directly to the Hot Location area)
          Positioned(
            right: 20,
            bottom: 160,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF121421),
              foregroundColor: Colors.white,
              onPressed: _resetCameraToHottestPin,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Toggle Action Overlay Panel (Bottom Center)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121421),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Live Now',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _toggleLabel('Official\nStation Data', _isOfficialData),
                      const SizedBox(width: 8),
                      Switch(
                        value: !_isOfficialData,
                        onChanged: (v) {
                          setState(() {
                            _isOfficialData = !v;
                          });
                          // Smoothly jump back to auto focus the new hot pin data subset
                          Future.delayed(const Duration(milliseconds: 100), _resetCameraToHottestPin);
                        },
                        activeColor: Colors.orange,
                        inactiveThumbColor: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _toggleLabel('User\nReported Temp.', !_isOfficialData),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleLabel(String text, bool active) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
        color: active ? Colors.black : Colors.black38,
      ),
    );
  }

  Widget _buildHeatPin(String temp, Color color) {
    return CustomPaint(
      painter: TeardropPainter(color),
      child: Container(
        width: 50,
        height: 60,
        padding: const EdgeInsets.only(bottom: 14),
        alignment: Alignment.center,
        child: Text(
          '$temp°',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}

// Custom Painter to draw the clean Teardrop shape over OpenStreetMap coordinates
class TeardropPainter extends CustomPainter {
  final Color color;
  TeardropPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.quadraticBezierTo(0, size.height * 0.7, 0, size.width / 2);
    path.arcToPoint(Offset(size.width, size.width / 2), radius: Radius.circular(size.width / 2));
    path.quadraticBezierTo(size.width, size.height * 0.7, size.width / 2, size.height);
    canvas.drawPath(path, paint);

    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}