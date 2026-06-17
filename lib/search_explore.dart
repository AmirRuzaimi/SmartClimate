import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // Hides conflict class
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchExploreScreen extends StatefulWidget {
  final double currentLat;
  final double currentLng;
  final String locationHeaderName;
  final Function(double, double, String) onLocationChanged;

  const SearchExploreScreen({
    super.key,
    required this.currentLat,
    required this.currentLng,
    required this.locationHeaderName,
    required this.onLocationChanged,
  });

  @override
  State<SearchExploreScreen> createState() => _SearchExploreScreenState();
}

class _SearchExploreScreenState extends State<SearchExploreScreen> {
  // Free OpenStreetMap controller instance
  final MapController _osmMapController = MapController();

  List<Map<String, dynamic>> _allPlacesList = [];
  List<Map<String, dynamic>> _filteredPlacesList = [];
  String _selectedCategory = "All";

  @override
  void initState() {
    super.initState();
    _listenToCommunityPins();
  }

  @override
  void didUpdateWidget(covariant SearchExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLat != widget.currentLat || oldWidget.currentLng != widget.currentLng) {
      _moveCameraToLocation(widget.currentLat, widget.currentLng);
    }
  }

  // Listens live to Firebase Firestore database clusters
  void _listenToCommunityPins() {
    FirebaseFirestore.instance.collection('community_pins').snapshots().listen((snapshot) {
      List<Map<String, dynamic>> temporaryList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        double lat = data['latitude'];
        double lng = data['longitude'];
        String name = data['name'] ?? 'Unnamed Place';
        String category = data['category'] ?? 'General';
        String creator = data['createdBy'] ?? 'Community Member';

        Color displayColor = Colors.orange;
        if (category == "Parks") {
          displayColor = Colors.green;
        } else if (category == "Water Stations") {
          displayColor = Colors.cyan;
        } else if (category == "Cooling Areas") {
          displayColor = Colors.blue;
        } else if (category == "Clinics") {
          displayColor = Colors.red;
        }

        temporaryList.add({
          'id': doc.id,
          'name': name,
          'category': category,
          'point': LatLng(lat, lng), // Parsed as free latlong2 geometry point
          'color': displayColor,
          'creator': creator
        });
      }

      if (mounted) {
        setState(() {
          _allPlacesList = temporaryList;
          _applyCategoryFilter(_selectedCategory);
        });
      }
    });
  }

  void _applyCategoryFilter(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == "All") {
        _filteredPlacesList = _allPlacesList;
      } else {
        _filteredPlacesList = _allPlacesList.where((place) {
          return place['category'] == category;
        }).toList();
      }
    });
  }

  void _moveCameraToLocation(double lat, double lng) {
    _osmMapController.move(LatLng(lat, lng), 14.5);
  }

  void _showDeleteConfirmDialog(String docId, String placeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Location?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("Are you sure you want to delete '$placeName' from the community map?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('community_pins').doc(docId).delete();
                if (mounted) Navigator.pop(context);
                _showSnackBar("Successfully removed '$placeName'");
              } catch (e) {
                _showSnackBar("Error deleting pin: $e");
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Pops open whenever a user long-presses on the map coordinates window canvas
  void _showAddPinDialog(LatLng tappedPoint) {
    final TextEditingController nameController = TextEditingController();
    String chosenCategory = "Parks";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Share This Location", style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Help the SmartClimate community by tagging this environmental area!", style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: "Place Name (e.g., Perdana Park)",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: chosenCategory,
                decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300))
                ),
                items: ["Parks", "Indoor Activities", "Clinics", "Water Stations", "Cooling Areas"]
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => chosenCategory = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
              ),
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance.collection('community_pins').add({
                    'name': nameController.text.trim(),
                    'category': chosenCategory,
                    'latitude': tappedPoint.latitude,
                    'longitude': tappedPoint.longitude,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': 'Amir', // Keeps attribution tagging functionality
                  });
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text("Save Pin", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER NAVIGATION BAR
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.location_on, color: Colors.orange.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Explore Areas", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 0.5)),
                      Text(widget.locationHeaderName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. NEARBY CLIMATE MAP FRAME HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategory == "All" ? "NEARBY CLIMATE MAP" : "NEARBY MAP ($_selectedCategory)",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black54, letterSpacing: 0.5),
                  ),
                  const Text("Long-press map to pin spot", style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
              const SizedBox(height: 10),

              // 3. FREE MAP CONTAINER WINDOW LAYER
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, spreadRadius: 2)],
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: FlutterMap(
                    mapController: _osmMapController,
                    options: MapOptions(
                      initialCenter: LatLng(widget.currentLat, widget.currentLng),
                      initialZoom: 13.5,
                      // Capture long press event triggers on OpenStreetMap
                      onLongPress: (tapPosition, point) => _showAddPinDialog(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.suncare.app',
                      ),
                      MarkerLayer(
                        markers: _filteredPlacesList.map((place) {
                          return Marker(
                            point: place['point'],
                            width: 120, // Clean explicit width assignment
                            height: 85, // Expanded height slightly to give layouts vertical breathing room
                            alignment: Alignment.topCenter,
                            child: GestureDetector(
                              onTap: () => _showDeleteConfirmDialog(place['id'], place['name']),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // ─── OVERFLOW FIX: Added explicit constraints and maxLines layout safety ───
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                                      border: Border.all(color: place['color'], width: 1.2),
                                    ),
                                    child: Text(
                                      place['name'],
                                      textAlign: TextAlign.center,
                                      maxLines: 1, // Locks string to a single line
                                      overflow: TextOverflow.ellipsis, // Safely cuts into "..." if it's too long
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.location_on, color: place['color'], size: 26),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. CATEGORIES FILTER GRID (BELOW MAP)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("FILTER BY CATEGORY", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black54, letterSpacing: 1.1)),
                  if (_selectedCategory != "All")
                    TextButton(
                      onPressed: () => _applyCategoryFilter("All"),
                      child: Text("Clear Filter", style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 95,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    CategoryIconWidget(
                      icon: Icons.park,
                      label: "Parks",
                      isSelected: _selectedCategory == "Parks",
                      activeGradient: [Colors.green.shade400, Colors.green.shade700],
                      onTap: () => _applyCategoryFilter("Parks"),
                    ),
                    CategoryIconWidget(
                      icon: Icons.fitness_center,
                      label: "Indoor",
                      isSelected: _selectedCategory == "Indoor Activities",
                      activeGradient: [Colors.orange.shade400, Colors.orange.shade700],
                      onTap: () => _applyCategoryFilter("Indoor Activities"),
                    ),
                    CategoryIconWidget(
                      icon: Icons.local_hospital,
                      label: "Clinics",
                      isSelected: _selectedCategory == "Clinics",
                      activeGradient: [Colors.red.shade400, Colors.red.shade700],
                      onTap: () => _applyCategoryFilter("Clinics"),
                    ),
                    CategoryIconWidget(
                      icon: Icons.opacity,
                      label: "Water",
                      isSelected: _selectedCategory == "Water Stations",
                      activeGradient: [Colors.cyan.shade400, Colors.blue.shade600],
                      onTap: () => _applyCategoryFilter("Water Stations"),
                    ),
                    CategoryIconWidget(
                      icon: Icons.ac_unit,
                      label: "Cooling",
                      isSelected: _selectedCategory == "Cooling Areas",
                      activeGradient: [Colors.blue.shade400, Colors.indigo.shade700],
                      onTap: () => _applyCategoryFilter("Cooling Areas"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // DYNAMIC COMMUNITY SHARED PLACES CARDS FEED PANEL
              Row(
                children: [
                  Icon(Icons.people_outline, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 6),
                  const Text("COMMUNITY SHARED PLACES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black54, letterSpacing: 0.5)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Text("${_filteredPlacesList.length} Active", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                  )
                ],
              ),
              const SizedBox(height: 12),

              _filteredPlacesList.isEmpty
                  ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                child: const Center(child: Text("No community places pinned under this filter yet.", style: TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic))),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredPlacesList.length,
                itemBuilder: (context, index) {
                  final place = _filteredPlacesList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onLongPress: () => _showDeleteConfirmDialog(place['id'], place['name']),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (place['color'] as Color).withOpacity(0.1),
                          child: Icon(Icons.pin_drop, color: place['color'] as Color, size: 20),
                        ),
                        title: Text(place['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        subtitle: Text("Tagged as: ${place['category']} • By: ${place['creator']}", style: const TextStyle(fontSize: 12, color: Colors.black45)),
                        trailing: Container(
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                          child: IconButton(
                            icon: Icon(Icons.near_me, color: Colors.orange.shade700, size: 18),
                            onPressed: () => _moveCameraToLocation(place['point'].latitude, place['point'].longitude),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── EXTRACTED WIDGET DESIGN LAYOUTS (ADDED TO THE BOTTOM) ───

class CategoryIconWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final List<Color> activeGradient;
  final VoidCallback onTap;

  const CategoryIconWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeGradient,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 85,
        margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
        decoration: BoxDecoration(
          color: isSelected ? null : Colors.white,
          gradient: isSelected ? LinearGradient(colors: activeGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
          boxShadow: [
            BoxShadow(
                color: isSelected ? activeGradient[1].withOpacity(0.3) : Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 3)
            )
          ],
          border: isSelected ? null : Border.all(color: Colors.grey.shade200, width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }
}

class ActivitySubCardWidget extends StatelessWidget {
  final IconData icon;
  final String label;

  const ActivitySubCardWidget({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
          ]
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: Colors.black),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}