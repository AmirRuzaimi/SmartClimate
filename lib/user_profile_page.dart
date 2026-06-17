import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfilePage extends StatefulWidget {
  final VoidCallback onLogout; // Accepts callback link from DashboardHome
  const UserProfilePage({super.key, required this.onLogout});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  int _selectedTab = 0;
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final String _displayName = FirebaseAuth.instance.currentUser?.displayName ?? "User Account";

  int _calculateTrustScore(List<QueryDocumentSnapshot> userPosts) {
    if (userPosts.isEmpty) return 50;

    int totalConfirmations = 0;
    for (var doc in userPosts) {
      final data = doc.data() as Map<String, dynamic>;
      final List likedBy = data['likedBy'] ?? [];
      totalConfirmations += likedBy.length;
    }

    int calculated = 50 + (totalConfirmations * 5);
    return calculated > 100 ? 100 : calculated;
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to log out?"),
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
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Close Profile Page back to Main Shell
                await FirebaseAuth.instance.signOut();
                widget.onLogout(); // Dispatches back to Main Shell Gatekeeper
              },
              child: const Text("Logout", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // ─── OUTER STREAM: TRACKS USER SOCIAL POSTS ────────────────────────────
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_posts')
            .where('uid', isEqualTo: _currentUid)
            .snapshots(),
        builder: (context, postSnapshot) {
          if (postSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userPosts = postSnapshot.data?.docs ?? [];
          final int trustScore = _calculateTrustScore(userPosts);

          // ─── INNER STREAM: TRACKS WELLNESS ACHIEVEMENTS LIVE ──────────────────
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUid)
                .snapshots(),
            builder: (context, userSnapshot) {
              List dynamicAchievements = [];

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                dynamicAchievements = userData['achievements'] ?? [];
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIdentityCard(trustScore),
                    const SizedBox(height: 20),
                    _buildContributionHeatmap(userPosts.length),
                    const SizedBox(height: 20),
                    // Passed down real-time achievements array to gallery builder
                    _buildAchievementGallery(userPosts.length, trustScore, dynamicAchievements),
                    const SizedBox(height: 20),
                    _buildMyReportsSection(userPosts),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildIdentityCard(int trustScore) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.orange.shade50,
                child: const Icon(Icons.person, size: 40, color: Colors.orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 20),
                          tooltip: "Logout Account",
                          onPressed: () => _showLogoutDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Active SunCare community member reporting local weather anomalies and environment alerts.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: trustScore / 100.0,
                          backgroundColor: Colors.grey.shade200,
                          color: trustScore >= 75 ? Colors.green : Colors.orange,
                          strokeWidth: 5,
                        ),
                      ),
                      Text(
                        '$trustScore%',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: trustScore >= 75 ? Colors.green : Colors.orange
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Trust Score',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.location_on, size: 14, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  'Primary District: Kota Bharu Central',
                  style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionHeatmap(int reportCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contribution Heatmap',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Mar', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Apr', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('May', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Jun', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Jul', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Aug', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 24,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              Color blockColor = Colors.grey.shade100;

              if (reportCount > 0 && index == 22) {
                blockColor = Colors.orange.shade300;
              } else if (reportCount > 3 && index == 15) {
                blockColor = Colors.orange.shade600;
              } else if (reportCount > 0 && index % 7 == 0) {
                blockColor = Colors.orange.shade100;
              }

              return Container(
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementGallery(int reportCount, int trustScore, List dynamicAchievements) {
    final List<Map<String, dynamic>> badges = [
      {
        'icon': Icons.flash_on,
        'name': 'First Responder',
        'unlocked': reportCount >= 1,
        'color': Colors.amber
      },
      {
        'icon': Icons.local_drink,
        'name': 'Hydration Hero',
        'unlocked': dynamicAchievements.contains('Hydration Master') || reportCount >= 3,
        'color': Colors.blue
      },
      {
        'icon': Icons.gpp_good_rounded,
        'name': 'Climate Resilient',
        'unlocked': dynamicAchievements.contains('Climate Resilient'),
        'color': Colors.orange.shade700
      },
      {
        'icon': Icons.verified_user_outlined,
        'name': 'Reliable Source',
        'unlocked': trustScore >= 70,
        'color': Colors.teal
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achievement Gallery',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1),
        ),
        const SizedBox(height: 12),
        // ─── SWITCHED TO AN AUTOWRAP GRID TO PREVENT CUT EDGES ────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Main viewport layout controller handles scrolling
          itemCount: badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,         // Forces all 4 cards to share width equally
            crossAxisSpacing: 8,       // Horizontal separation safety margins
            mainAxisExtent: 105,       // Uniform vertical row heights
          ),
          itemBuilder: (context, index) {
            final badge = badges[index];
            final bool isUnlocked = badge['unlocked'];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isUnlocked ? badge['color'].withOpacity(0.1) : Colors.grey.shade100,
                    child: Icon(
                        badge['icon'],
                        color: isUnlocked ? badge['color'] : Colors.grey.shade400,
                        size: 18
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    badge['name'],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9.5, // Rescaled font to prevent bounding boxes from breaking
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.black87 : Colors.grey,
                        height: 1.1
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMyReportsSection(List<QueryDocumentSnapshot> userPosts) {
    final activeReports = userPosts.where((doc) {
      final text = (doc.data() as Map<String, dynamic>)['text'] ?? '';
      return !text.toString().toLowerCase().contains('resolved');
    }).toList();

    final archivedReports = userPosts.where((doc) {
      final text = (doc.data() as Map<String, dynamic>)['text'] ?? '';
      return text.toString().toLowerCase().contains('resolved');
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Reports',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildTabButton('Active (${activeReports.length})', 0),
            _buildTabButton('Archived (${archivedReports.length})', 1),
          ],
        ),
        const SizedBox(height: 12),
        _selectedTab == 0
            ? _buildReportsList(activeReports, isArchive: false)
            : _buildReportsList(archivedReports, isArchive: true),
      ],
    );
  }

  Widget _buildTabButton(String title, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.orange : Colors.grey.shade300,
                width: isSelected ? 3.0 : 1.0,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? Colors.orange : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList(List<QueryDocumentSnapshot> posts, {required bool isArchive}) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            isArchive ? "No resolved reports yet." : "No current active alert reports.",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index].data() as Map<String, dynamic>;
        final List likedBy = post['likedBy'] ?? [];

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(
                isArchive ? Icons.check_circle : Icons.warning_amber_rounded,
                color: isArchive ? Colors.green : Colors.orange
            ),
            title: Text(
                post['text'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
            ),
            subtitle: Text(
                '${post['time'] ?? 'Just Now'} • ${likedBy.length} Confirmations',
                style: const TextStyle(fontSize: 11)
            ),
            trailing: const Icon(Icons.chevron_right, size: 16),
          ),
        );
      },
    );
  }
}