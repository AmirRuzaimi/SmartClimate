import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_thread_page.dart'; // Imported the 2.2 discussion thread module!

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final TextEditingController _postController = TextEditingController();
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final String _currentName = FirebaseAuth.instance.currentUser?.displayName ?? "Ahmad K.";
  bool _isSubmitting = false;

  final List<String> _trendingHashtags = [
    "#KotaBharuHeatwave",
    "#RainyMorning",
    "#HazeAlert",
    "#FlashFlood"
  ];

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _createNewPost() async {
    if (_postController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('community_posts').add({
        'uid': _currentUid,
        'authorName': _currentName,
        'text': _postController.text.trim(),
        'time': 'Just Now',
        'likedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
        'locationTag': 'Kota Bharu Central',
        'isVerifiedLocal': true,
        // Added default spatial markers for newly generated feed items
        'latitude': 6.1254,
        'longitude': 102.2386,
      });

      _postController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alert broadcasted to live wall!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to broadcast alert: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _toggleConfirmation(String docId, List likedByList) async {
    final docRef = FirebaseFirestore.instance.collection('community_posts').doc(docId);

    if (likedByList.contains(_currentUid)) {
      await docRef.update({
        'likedBy': FieldValue.arrayRemove([_currentUid])
      });
    } else {
      await docRef.update({
        'likedBy': FieldValue.arrayUnion([_currentUid])
      });
    }
  }

  void _shareToSafetyModule(String alertText) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade800,
        content: Row(
          children: const [
            Icon(Icons.gpp_good, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text("Escalated! Report copied over to Parvin's Safety Alerts system.")),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePost(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('community_posts').doc(docId).delete();
    } catch (e) {
      debugPrint("Error deleting post: $e");
    }
  }

  void _appendHashtag(String tag) {
    setState(() {
      _postController.text = "${_postController.text} $tag ".trimLeft();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        // ─── FIXED: Swapped out the old menu lines for the discussion chat asset ───
        leading: IconButton(
          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black87),
          tooltip: 'General Location Discussion',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LocationThreadPage(
                  postId: "global_general_chat",
                  lat: 6.1254,
                  lng: 102.2386,
                  locationName: "General Location Thread",
                ),
              ),
            );
          },
        ),
        title: const Text(''), // Removed the word "App" cleanly from the header bar layout
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black87), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search, color: Colors.black87), onPressed: () {}),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Camera attachment stream placeholder triggered.")),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostCreatorField(),
          _buildTrendingHashtagsRow(),
          Expanded(child: _buildLiveFeedStream()),
        ],
      ),
    );
  }

  Widget _buildPostCreatorField() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.shade50,
                child: const Icon(Icons.campaign, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _postController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: "Notice a climate hazard? Share it with neighbors...",
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_postController.text.trim().isNotEmpty)
                IconButton(
                  icon: Icon(Icons.send, color: Colors.orange.shade800),
                  onPressed: _createNewPost,
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingHashtagsRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Trending Hashtags",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _trendingHashtags.length,
              itemBuilder: (context, index) {
                final tag = _trendingHashtags[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    backgroundColor: Colors.blueGrey.shade50,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    label: Text(
                      tag,
                      style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _appendHashtag(tag),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveFeedStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error syncing live feed."));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "Live wall is quiet.\nTap trending tags or broadcast an alert above!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final post = doc.data() as Map<String, dynamic>;
            final String docId = doc.id;
            final String authorUid = post['uid'] ?? "";
            final List likedBy = post['likedBy'] ?? [];
            final bool hasConfirmed = likedBy.contains(_currentUid);

            // Dynamically safely parsing geospatial marker assignments passed from Firestore
            final double lat = (post['latitude'] ?? 6.1254).toDouble();
            final double lng = (post['longitude'] ?? 102.2386).toDouble();
            final String locationName = post['locationTag'] ?? 'Kota Bharu Central';

            // ─── WRAP THE ENTIRE ALERT CARD IN AN INKWELL TARGET ────
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationThreadPage(
                      postId: docId,
                      lat: lat,
                      lng: lng,
                      locationName: locationName,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.orange.shade100,
                                child: const Icon(Icons.account_circle, size: 24, color: Colors.orange),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        post['authorName'] ?? 'Ahmad K.',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE3F2FD),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '✓ Verified Local',
                                          style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "• ${post['time'] ?? 'Just Now'}",
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (authorUid == _currentUid)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                              onSelected: (val) => _deletePost(docId),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete Post', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        post['text'] ?? '',
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey.shade400),
                            const SizedBox(height: 6),
                            Text(
                              "User-Submitted Image/Video Component",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            locationName,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: hasConfirmed ? Colors.green : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _toggleConfirmation(docId, likedBy),
                              icon: Icon(
                                hasConfirmed ? Icons.check_circle : Icons.thumb_up_outlined,
                                size: 16,
                                color: hasConfirmed ? Colors.green : Colors.black87,
                              ),
                              label: Text(
                                "Confirm (${likedBy.length})",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: hasConfirmed ? Colors.green : Colors.black87
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _shareToSafetyModule(post['text'] ?? ''),
                              icon: const Icon(Icons.gpp_maybe, size: 16, color: Colors.black87),
                              label: const Text(
                                "Share to Safety",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}