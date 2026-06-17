import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationThreadPage extends StatefulWidget {
  final String postId;
  final double lat;
  final double lng;
  final String locationName;

  const LocationThreadPage({
    super.key,
    required this.postId,
    required this.lat,
    required this.lng,
    required this.locationName,
  });

  @override
  State<LocationThreadPage> createState() => _LocationThreadPageState();
}

class _LocationThreadPageState extends State<LocationThreadPage> {
  final TextEditingController _commentController = TextEditingController();
  final MapController _mapController = MapController();

  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final String _currentName = FirebaseAuth.instance.currentUser?.displayName ?? "Anonymous Neighbor";
  String _selectedSort = "Newest";

  // Dynamic coordinate states that the user can actively modify
  late double _currentLat;
  late double _currentLng;
  bool _isEditingLocation = false;
  bool _isSubmittingLocation = false;

  @override
  void initState() {
    super.initState();
    // Initialize map positions with the original values passed from the feed screen
    _currentLat = widget.lat;
    _currentLng = widget.lng;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ─── SAFE WRITER: WORKS FOR BOTH EXISTING AND NEW FLOATING MARKERS ───────
  Future<void> _saveNewLocation() async {
    setState(() => _isSubmittingLocation = true);
    try {
      // Using .set with merge: true handles both creating new pins and updating old ones safely!
      await FirebaseFirestore.instance
          .collection('community_posts')
          .doc(widget.postId)
          .set({
        'latitude': _currentLat,
        'longitude': _currentLng,
        'locationTag': widget.postId == "global_general_chat"
            ? "General Community Hub"
            : widget.locationName,
        'lastMovedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isEditingLocation = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Marker position successfully saved to the cloud!"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update marker position: $e")),
        );
      }
    } finally {
      setState(() => _isSubmittingLocation = false);
    }
  }

  // ─── ADD A NEW REPLY TO FIRESTORE DISCUSSION NEST ─────────────────────────
  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    _commentController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('community_posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'authorName': _currentName,
        'uid': _currentUid,
        'text': commentText,
        'createdAt': FieldValue.serverTimestamp(),
        'isChild': false,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not post comment: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditingLocation ? "Reposition Hazard Marker" : widget.locationName,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildLiveDynamicMapHeader(),
          _buildPinnedLiveStatusBanner(),
          Expanded(child: _buildLiveFirestoreCommentStream()),
          _buildQuickReactsBar(),
          _buildSortToggleBar(),
          _buildCommentInputField(),
        ],
      ),
    );
  }

  // ─── INTERACTIVE MAP HEADER WITH LOCATION CHANGING CAPABILITIES ────────────
  Widget _buildLiveDynamicMapHeader() {
    final LatLng dynamicPoint = LatLng(_currentLat, _currentLng);

    return SizedBox(
      width: double.infinity,
      height: 180,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: dynamicPoint,
              zoom: 14.0,
              maxZoom: 18,
              minZoom: 11,
              // Tapping the map re-centers the pin only if edit mode is toggled on
              onTap: (tapPosition, point) {
                if (_isEditingLocation) {
                  setState(() {
                    _currentLat = point.latitude;
                    _currentLng = point.longitude;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sunclimate.community',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: dynamicPoint,
                    color: _isEditingLocation
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.blue.withOpacity(0.12),
                    borderColor: _isEditingLocation ? Colors.orange.shade700 : Colors.blue.shade600,
                    borderStrokeWidth: 1.5,
                    useRadiusInMeter: true,
                    radius: 1500,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: dynamicPoint,
                    child: Icon(
                      Icons.location_pin,
                      color: _isEditingLocation ? Colors.orange.shade800 : Colors.red.shade800,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Left Badge: Guide Text Tracker
          Positioned(
            top: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
              child: Text(
                _isEditingLocation ? "Tap Map to Reposition Pin" : "Active Radius: 1.5km",
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Right Action Button Overlay: Controls the edit states
          Positioned(
            top: 10,
            right: 12,
            child: Row(
              children: [
                if (_isEditingLocation) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentLat = widget.lat;
                        _currentLng = widget.lng;
                        _isEditingLocation = false;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.close, size: 14, color: Colors.black87),
                    ),
                  ),
                ],
                GestureDetector(
                  onTap: () {
                    if (_isEditingLocation) {
                      _saveNewLocation();
                    } else {
                      setState(() => _isEditingLocation = true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isEditingLocation ? Colors.green.shade700 : Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: _isSubmittingLocation
                        ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))
                    )
                        : Row(
                      children: [
                        Icon(_isEditingLocation ? Icons.check : Icons.edit_location_alt, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _isEditingLocation ? "Confirm Spot" : "Change Area",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIVE PINNED STATUS ACCORDING TO THE ACTIVE THREAD CONTEXT ──────────────
  Widget _buildPinnedLiveStatusBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.stars, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Discussion Zone", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    _isEditingLocation
                        ? "Moving target: [${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}]"
                        : "Syncing live coordinate thread logs...",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Chip(
            backgroundColor: _isEditingLocation ? Colors.orange.shade100 : Colors.orange.shade50,
            side: BorderSide.none,
            label: Text(
              _isEditingLocation ? "Editing" : "Active",
              style: TextStyle(color: Colors.orange.shade900, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  // ─── FIRESTORE COMMENT STREAM SUBCOLLECTION LOADER ─────────────────────────
  Widget _buildLiveFirestoreCommentStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final commentDocs = snapshot.data!.docs;

        if (commentDocs.isEmpty) {
          return Center(
            child: Text(
              "No replies posted here yet.\nBe the first to update neighbors inside this zone!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.4),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: commentDocs.length,
          itemBuilder: (context, index) {
            final comment = commentDocs[index].data() as Map<String, dynamic>;
            final bool isChild = comment['isChild'] ?? false;

            return Padding(
              padding: EdgeInsets.only(left: isChild ? 24.0 : 0.0, bottom: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.person, size: 14, color: Colors.orange.shade700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['authorName'] ?? 'Community Member',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment['text'] ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickReactsBar() {
    final List<IconData> reactionIcons = [Icons.wb_sunny, Icons.water_drop, Icons.bolt, Icons.masks];
    final List<Color> iconColors = [Colors.amber, Colors.blue, Colors.purple, Colors.teal];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const Text("Quick Reacts", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(reactionIcons.length, (i) {
              return InkWell(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: iconColors[i].withOpacity(0.1)),
                  child: Icon(reactionIcons[i], color: iconColors[i], size: 22),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSortToggleBar() {
    final List<String> sortOptions = ["Newest", "Most Confirmed", "Emergency Only"];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        children: [
          const Text("Sort", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 26,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sortOptions.length,
                itemBuilder: (context, index) {
                  final opt = sortOptions[index];
                  final bool isSelected = _selectedSort == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selectedColor: Colors.orange.shade100,
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(opt, style: TextStyle(fontSize: 10, color: isSelected ? Colors.orange.shade900 : Colors.black87)),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedSort = opt);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputField() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(hintText: "Write a reply to this thread...", border: InputBorder.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.orange.shade700,
              radius: 18,
              child: IconButton(
                icon: const Icon(Icons.send, size: 14, color: Colors.white),
                onPressed: _submitComment,
              ),
            )
          ],
        ),
      ),
    );
  }
}