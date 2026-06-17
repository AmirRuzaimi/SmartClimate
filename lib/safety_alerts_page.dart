import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SafetyAlertsPage extends StatefulWidget {
  final VoidCallback? onSeeAllReports;

  const SafetyAlertsPage({super.key, this.onSeeAllReports});

  @override
  State<SafetyAlertsPage> createState() => _SafetyAlertsPageState();
}

class _SafetyAlertsPageState extends State<SafetyAlertsPage> {
  // ─── LIVE OPEN-METEO WEATHER VARIABLES ───
  bool _isWeatherLoading = true;
  String _liveTemp = "38°C";
  String _liveUVScale = "EXTREME";

  // ─── HOURLY TREND SELECTED STATE VARIABLE ───
  int _selectedHourIndex = 2; // Default selection: 2 PM

  @override
  void initState() {
    super.initState();
    _fetchLiveWeatherForKB();
  }

  Future<void> _fetchLiveWeatherForKB() async {
    try {
      final response = await http.get(Uri.parse(
          "https://api.open-meteo.com/v1/forecast?latitude=6.1254&longitude=102.2381&current=temperature_2m,uv_index&timezone=auto"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        double tempC = (current['temperature_2m'] ?? 38.0).toDouble();
        double uv = (current['uv_index'] ?? 11.0).toDouble();

        if (mounted) {
          setState(() {
            _liveTemp = "${tempC.toStringAsFixed(0)}°C";
            _liveUVScale = _getUVScaleString(uv);
            _isWeatherLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isWeatherLoading = false);
    }
  }

  String _getUVScaleString(double uv) {
    if (uv <= 2) return "LOW";
    if (uv <= 5) return "MODERATE";
    if (uv <= 7) return "HIGH";
    if (uv <= 10) return "VERY HIGH";
    return "EXTREME";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => _showNotificationsDialog(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wb_sunny_outlined, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Text(
              'SmartClimate',
              style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Text(' Community', style: TextStyle(color: Colors.grey, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () => _showNotificationsDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildWeatherCard(),
            const SizedBox(height: 20),
            _buildAlertBanner(),
            const SizedBox(height: 20),
            _buildHourlyTrendButton(context),
            const SizedBox(height: 25),
            _buildQuickActions(context),
            const SizedBox(height: 25),
            _buildCommunityReportsHeader(context),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('community_posts').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No community alerts reported yet. Be the first!"));
                }
                final topDoc = snapshot.data!.docs.first;
                return _buildMainFeedCard(topDoc);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Weather Card ────────────────────────────────────────────────────────────
  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.wb_sunny, size: 48, color: Colors.orange),
              const SizedBox(height: 8),
              _isWeatherLoading
                  ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_liveTemp, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Text('Sunny', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('UV INDEX', style: TextStyle(letterSpacing: 1.2, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                _liveUVScale,
                style: TextStyle(
                    color: _liveUVScale == "EXTREME" || _liveUVScale == "VERY HIGH" ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text('Today, 12 June', style: TextStyle(color: Colors.black54)),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  Text(' Kota Bharu', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('EXTREME HEAT ALERT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _AlertBulletPoint(text: 'Avoid outdoor activities from 12PM – 4PM'),
                    _AlertBulletPoint(text: 'Drink more water'),
                    _AlertBulletPoint(text: 'Wear light clothing'),
                    _AlertBulletPoint(text: 'Stay in cool places'),
                  ],
                ),
              ),
              const Icon(Icons.thermostat, size: 60, color: Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyTrendButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HourlyTrendPage(
                initialSelectedIndex: _selectedHourIndex,
                onIndexChanged: (index) {
                  setState(() {
                    _selectedHourIndex = index;
                  });
                },
              ),
            ),
          );
        },
        icon: const Icon(Icons.show_chart, color: Colors.white),
        label: const Text('View 24-Hour Temperature Trend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK ACTION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickActionButton(icon: Icons.local_hospital_outlined, label: 'Nearest\nClinic', onTap: () => _showNearestClinics(context)),
            _QuickActionButton(icon: Icons.phone_in_talk_outlined, label: 'Call\nEmergency', onTap: () => _showEmergencyNumbers(context)),
            _QuickActionButton(icon: Icons.ac_unit_outlined, label: 'Cooling\nCenters', onTap: () => _showCoolingCenters(context)),
          ],
        ),
      ],
    );
  }

  Widget _buildCommunityReportsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('COMMUNITY REPORTS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        TextButton(
          onPressed: () => _showAllReports(context),
          child: Row(
            children: const [
              Text('See all', style: TextStyle(color: Colors.grey)),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainFeedCard(DocumentSnapshot doc) {
    final post = doc.data() as Map<String, dynamic>;
    final List commentsList = post['comments'] ?? [];
    final List likedBy = post['likedBy'] ?? [];
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final bool isLikedByMe = likedBy.contains(currentUid);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.orange[100], child: const Icon(Icons.person, color: Colors.orange)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(post['time'] ?? 'Just Now', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post['text'] ?? '', style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          Text(post['tags'] ?? '#Community', style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _showAllReports(context),
                icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                label: Text(
                  commentsList.isEmpty ? 'Comment' : 'Comments (${commentsList.length})',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  if (isLikedByMe) {
                    await FirebaseFirestore.instance.collection('community_posts').doc(doc.id).update({
                      'likedBy': FieldValue.arrayRemove([currentUid])
                    });
                  } else {
                    await FirebaseFirestore.instance.collection('community_posts').doc(doc.id).update({
                      'likedBy': FieldValue.arrayUnion([currentUid])
                    });
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      isLikedByMe ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                      size: 20,
                      color: isLikedByMe ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text('${likedBy.length}', style: TextStyle(color: isLikedByMe ? Colors.orange : Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔔 Notifications'),
        content: const Text(
          '⚠️ 10:00 AM — Extreme Heat Warning\nUV Index EXTREME until 4 PM\n\n'
              '💧 9:30 AM — Hydration Reminder\nDrink at least 2L of water today',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showNearestClinics(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🏥 Nearest Clinics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _ClinicItem(name: 'Klinik Kesihatan Kota Bharu', address: 'Jalan Hospital', phone: '09-748 5000', hours: '8 AM – 5 PM'),
            Divider(),
            _ClinicItem(name: 'Klinik Pakar An-Nur', address: 'Jalan Dato\' Pati', phone: '09-744 8888', hours: '24 Hours'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showEmergencyNumbers(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Emergency Contacts'),
        content: const Text('🚑 Ambulance: 999\n🚒 Fire & Rescue: 994\n🏥 Hospital KB: 09-745 6000', style: TextStyle(height: 1.8)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showCoolingCenters(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❄️ Cooling Centers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _CoolingCenterItem(name: 'Pusat Komuniti KB', address: 'Jalan Sultan Ibrahim', hours: '10 AM – 6 PM', capacity: '150 people'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showAllReports(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InteractiveReportsSheet(),
    );
  }
}

// ─── REUSABLE UTILITY SUB-WIDGET COMPONENTS ───────────────────────────────────

class _AlertBulletPoint extends StatelessWidget {
  final String text;
  const _AlertBulletPoint({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Icon(icon, size: 34, color: Colors.orange[800]),
          ),
          const SizedBox(height: 8),
          SizedBox(width: 90, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ClinicItem extends StatelessWidget {
  final String name, address, phone, hours;
  const _ClinicItem({required this.name, required this.address, required this.phone, required this.hours});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏥 $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('📍 $address  |  📞 $phone', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text('⏰ $hours', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _CoolingCenterItem extends StatelessWidget {
  final String name, address, hours, capacity;
  const _CoolingCenterItem({required this.name, required this.address, required this.hours, required this.capacity});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('❄️ $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('📍 $address  |  ⏰ $hours', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text('👥 Capacity: $capacity', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── INTERACTIVE HOURLY TREND PAGE ───────────────────────────────────────────

class HourlyTrendPage extends StatefulWidget {
  final int initialSelectedIndex;
  final ValueChanged<int> onIndexChanged;

  const HourlyTrendPage({
    super.key,
    required this.initialSelectedIndex,
    required this.onIndexChanged,
  });

  @override
  State<HourlyTrendPage> createState() => _HourlyTrendPageState();
}

class _HourlyTrendPageState extends State<HourlyTrendPage> {
  late int _selectedIndex;

  static const List<Map<String, dynamic>> _hourlyData = [
    {'hour': '12 PM', 'temp': 32, 'icon': '☀️', 'advice': 'Temp is starting to rise. Secure shade vectors early.'},
    {'hour': '1 PM', 'temp': 33, 'icon': '☀️', 'advice': 'High UV expected. Stay indoors or utilize high-protection sun blocks.'},
    {'hour': '2 PM', 'temp': 34, 'icon': '🔥', 'advice': 'PEAK TEMPERATURE REACHED. Avoid open spaces and maximize hydration immediately.'},
    {'hour': '3 PM', 'temp': 34, 'icon': '🔥', 'advice': 'Peak extreme heat wave ongoing. Cooling stations are open at Pusat Komuniti.'},
    {'hour': '4 PM', 'temp': 33, 'icon': '☀️', 'advice': 'Atmospheric thermal index plateauing. Continue avoiding direct sunlight.'},
    {'hour': '5 PM', 'temp': 31, 'icon': '☀️', 'advice': 'Sub-surface heat radiant cooling beginning. Safe for light commute paths.'},
    {'hour': '6 PM', 'temp': 29, 'icon': '⛅', 'advice': 'Heat wave intensity dropped. Ideal timeframe for ambient community movement.'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _hourlyData[_selectedIndex];
    final bool isPeakSelected = selectedItem['temp'] >= 34;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F5),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Hourly Outlook', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _showPeakHeatDialog(context),
              child: Container(
                width: double.infinity, color: const Color(0xFFFFF3E0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: const [
                    Text('⚠️', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Expanded(child: Text('PEAK HEAT: 2 PM – 4 PM  |  Tap for safety tips', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 13))),
                    Icon(Icons.chevron_right, color: Color(0xFFE65100)),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('24-Hour Temperature Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  SizedBox(height: 220, child: CustomPaint(painter: _TemperatureGraphPainter(), size: const Size(double.infinity, 220))),
                ],
              ),
            ),
            Container(
              color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Hourly Forecast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List.generate(_hourlyData.length, (index) {
                        final data = _hourlyData[index];
                        final bool isHot = data['temp'] >= 34;
                        final bool isCurrentSelection = _selectedIndex == index;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                            });
                            widget.onIndexChanged(index);
                          },
                          child: Container(
                            width: 80, margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isCurrentSelection
                                  ? (isHot ? const Color(0xFFFFE0B2) : const Color(0xFFE3F2FD))
                                  : (isHot ? const Color(0xFFFFF3E0) : Colors.white),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCurrentSelection
                                    ? (isHot ? Colors.deepOrange : Colors.blue.shade700)
                                    : (isHot ? Colors.orange.shade200 : Colors.grey.shade200),
                                width: isCurrentSelection ? 2.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(data['hour'], style: TextStyle(fontSize: 12, fontWeight: isCurrentSelection ? FontWeight.bold : FontWeight.normal)),
                                const SizedBox(height: 8),
                                Text(data['icon'], style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 8),
                                Text('${data['temp']}°C', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isHot ? Colors.deepOrange : Colors.black87)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showAdviceDialog(context, selectedItem['hour'], selectedItem['temp'], selectedItem['advice']),
              child: Container(
                margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPeakSelected ? const Color(0xFFFFEBEE) : const Color(0xFFFFFDE7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isPeakSelected ? Colors.red.shade100 : const Color(0xFFFFF9C4)),
                ),
                child: Row(
                  children: [
                    Text(isPeakSelected ? '🔥' : '💡', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Actionable Advice Card (${selectedItem['hour']}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(selectedItem['advice'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showPeakHeatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Peak Heat Warning: 2PM – 4PM'),
        content: const Text('实时峰值: 34°C\n☀️ UV Index: Extreme\n\nTips:\n• Stay indoors\n• Drink water every 30 mins', style: TextStyle(fontSize: 14, height: 1.6)),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
      ),
    );
  }

  void _showAdviceDialog(BuildContext context, String hour, int temp, String advice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('💡 Heat Safety Advice — $hour'),
        content: Text('Target Forecast Metrics:\n🌡️ Temperature: $temp°C\n\nAdvisory Context:\n$advice\n\n💧 Baseline Requirement: Drink 250ml/hour minimal structural baseline.', style: TextStyle(fontSize: 14, height: 1.6)),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Understood'))],
      ),
    );
  }
}

// ─── Temperature Graph Painter ────────────────────────────────────────────────

class _TemperatureGraphPainter extends CustomPainter {
  static const List<Map<String, dynamic>> _data = [
    {'h': 0, 't': 18}, {'h': 4, 't': 13}, {'h': 7, 't': 12}, {'h': 12, 't': 28},
    {'h': 14, 't': 32}, {'h': 16, 't': 34}, {'h': 18, 't': 34}, {'h': 24, 't': 19},
  ];
  static const double _minTemp = 10; static const double _maxTemp = 40;
  static const double _padLeft = 36; static const double _padRight = 16;
  static const double _padTop = 16; static const double _padBottom = 28;

  double _x(double w, int hour) => _padLeft + (hour / 24.0) * (w - _padLeft - _padRight);
  double _y(double h, int temp) => _padTop + (h - _padTop - _padBottom) * (1 - (temp - _minTemp) / (_maxTemp - _minTemp));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final gridPaint = Paint()..color = Colors.grey.shade200..strokeWidth = 1;
    final labelStyle = const TextStyle(color: Colors.grey, fontSize: 10);

    for (int t in [10, 20, 30, 40]) {
      final y = _y(h, t);
      canvas.drawLine(Offset(_padLeft, y), Offset(w - _padRight, y), gridPaint);
      _drawText(canvas, '$t', Offset(0, y - 6), labelStyle);
    }
    for (int hr in [0, 6, 12, 18, 24]) {
      final x = _x(w, hr);
      _drawText(canvas, '${hr}h', Offset(x - 8, h - _padBottom + 6), labelStyle);
    }

    final peakPaint = Paint()..color = Colors.orange.withOpacity(0.12);
    final peakLeft = _x(w, 14); final peakRight = _x(w, 20);
    canvas.drawRect(Rect.fromLTRB(peakLeft, _padTop, peakRight, h - _padBottom), peakPaint);

    final linePaint = Paint()..color = const Color(0xFF1565C0)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final linePath = Path()..moveTo(_x(w, _data.first['h']), _y(h, _data.first['t']));
    for (int i = 1; i < _data.length; i++) {
      linePath.lineTo(_x(w, _data[i]['h']), _y(h, _data[i]['t']));
    }
    canvas.drawPath(linePath, linePaint);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, offset);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── REAL FIRESTORE INTERACTIVE COMMUNITY BOARD SHEET ────────────────────────

class _InteractiveReportsSheet extends StatefulWidget {
  const _InteractiveReportsSheet();

  @override
  State<_InteractiveReportsSheet> createState() => _InteractiveReportsSheetState();
}

class _InteractiveReportsSheetState extends State<_InteractiveReportsSheet> {
  String? _selectedPostId;
  final TextEditingController _inputController = TextEditingController();

  String _getCurrentUserShortName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    return "User";
  }

  void _handleSendText(Map<String, dynamic>? activePost) async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final String shortName = _getCurrentUserShortName();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final String timestampStr = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}";

    if (_selectedPostId != null) {
      final newComment = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'uid': uid,
        'name': shortName,
        'time': timestampStr,
        'text': text,
        'likes': []
      };

      await FirebaseFirestore.instance
          .collection('community_posts')
          .doc(_selectedPostId)
          .update({
        'comments': FieldValue.arrayUnion([newComment])
      });
    } else {
      await FirebaseFirestore.instance.collection('community_posts').add({
        'uid': uid,
        'name': shortName,
        'time': timestampStr,
        'text': text,
        'tags': '#SuncareAlert',
        'likedBy': [],
        'comments': []
      });
    }
    _inputController.clear();
    FocusScope.of(context).unfocus();
  }

  void _showEditPostDialog(String postId, String currentText) {
    final TextEditingController editPostController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Alert Post"),
        content: TextField(
          controller: editPostController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Update your alert details..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (editPostController.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('community_posts').doc(postId).update({
                'text': editPostController.text.trim()
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _showDeletePostDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text("Are you sure you want to remove this alert from the community board?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('community_posts').doc(postId).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showEditCommentDialog(String postId, List allComments, Map commentItem) {
    final TextEditingController editCommentController = TextEditingController(text: commentItem['text'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Reply"),
        content: TextField(
          controller: editCommentController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Update your reply..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (editCommentController.text.trim().isEmpty) return;
              for (var c in allComments) {
                if (c['id'] == commentItem['id']) {
                  c['text'] = editCommentController.text.trim();
                  break;
                }
              }
              await FirebaseFirestore.instance.collection('community_posts').doc(postId).update({
                'comments': allComments
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _deleteComment(String postId, Map commentItem) async {
    await FirebaseFirestore.instance.collection('community_posts').doc(postId).update({
      'comments': FieldValue.arrayRemove([commentItem])
    });
  }

  void _toggleCommentLike(String postId, List allComments, Map commentItem, String currentUid) async {
    for (var c in allComments) {
      if (c['id'] == commentItem['id']) {
        List likesList = c['likes'] ?? [];
        if (likesList.contains(currentUid)) {
          likesList.remove(currentUid);
        } else {
          likesList.add(currentUid);
        }
        c['likes'] = likesList;
        break;
      }
    }
    await FirebaseFirestore.instance.collection('community_posts').doc(postId).update({
      'comments': allComments
    });
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('community_posts').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            Map<String, dynamic>? activePostData;
            String? activeDocId;

            if (_selectedPostId != null) {
              final index = docs.indexWhere((d) => d.id == _selectedPostId);
              if (index != -1) {
                activeDocId = docs[index].id;
                activePostData = docs[index].data() as Map<String, dynamic>;
              } else {
                activePostData = null;
                _selectedPostId = null;
              }
            }

            return Column(
              children: [
                Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      if (_selectedPostId != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => setState(() => _selectedPostId = null),
                        ),
                      Text(
                        _selectedPostId != null ? 'Replies Thread' : '📢 Community Board',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: _selectedPostId != null && activePostData != null
                      ? _buildSingleThreadView(activeDocId!, activePostData, currentUid)
                      : _buildMainBoardListView(docs, currentUid),
                ),

                const Divider(height: 1),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: _selectedPostId != null ? "Write a community reply..." : "Report heat or water status in your area...",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: () => _handleSendText(activePostData),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
    );
  }

  Widget _buildMainBoardListView(List<QueryDocumentSnapshot> docs, String currentUid) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final post = doc.data() as Map<String, dynamic>;
        final List commentsList = post['comments'] ?? [];
        final List likedBy = post['likedBy'] ?? [];
        final bool isLikedByMe = likedBy.contains(currentUid);
        final bool isMyPost = post['uid'] == currentUid;

        return ListTile(
          leading: CircleAvatar(backgroundColor: Colors.orange[50], child: const Icon(Icons.person, color: Colors.orange)),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(post['time'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              if (isMyPost) ...[
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                  onPressed: () => _showEditPostDialog(doc.id, post['text'] ?? ''),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => _showDeletePostDialog(doc.id),
                ),
              ]
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(post['text'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 14)),
              const SizedBox(height: 6),
              Text(post['tags'] ?? '', style: const TextStyle(color: Colors.blue, fontSize: 12)),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedPostId = doc.id),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                    label: Text("Reply (${commentsList.length})", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(isLikedByMe ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, size: 18, color: isLikedByMe ? Colors.orange : Colors.grey),
                    onPressed: () async {
                      if (isLikedByMe) {
                        await FirebaseFirestore.instance.collection('community_posts').doc(doc.id).update({
                          'likedBy': FieldValue.arrayRemove([currentUid])
                        });
                      } else {
                        await FirebaseFirestore.instance.collection('community_posts').doc(doc.id).update({
                          'likedBy': FieldValue.arrayUnion([currentUid])
                        });
                      }
                    },
                  ),
                  Text("${likedBy.length}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleThreadView(String docId, Map<String, dynamic> post, String currentUid) {
    final List commentsList = post['comments'] ?? [];
    final bool isMyPost = post['uid'] == currentUid;

    return ListView(
      children: [
        Container(
          color: Colors.orange.shade50.withOpacity(0.3),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: Colors.orange[100], child: const Icon(Icons.person, color: Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(post['time'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (isMyPost) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                      onPressed: () => _showEditPostDialog(docId, post['text'] ?? ''),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () => _showDeletePostDialog(docId),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(post['text'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87)),
            ],
          ),
        ),
        const Divider(height: 1),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text("Replies", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),

        ...commentsList.map((commentItem) {
          final Map cMap = commentItem as Map;
          final List commentLikes = cMap['likes'] ?? [];
          final bool isCommentLikedByMe = commentLikes.contains(currentUid);
          final bool isMyComment = cMap['uid'] == currentUid;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 16, backgroundColor: Colors.blue.shade50, child: const Icon(Icons.person, size: 16, color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cMap['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(cMap['time'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          if (isMyComment) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showEditCommentDialog(docId, commentsList, cMap),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              constraints: const BoxConstraints(),
                              onPressed: () => _deleteComment(docId, cMap),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(cMap['text'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(isCommentLikedByMe ? Icons.favorite : Icons.favorite_border, size: 14, color: isCommentLikedByMe ? Colors.red : Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _toggleCommentLike(docId, commentsList, cMap, currentUid),
                          ),
                          const SizedBox(width: 4),
                          Text("${commentLikes.length}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}