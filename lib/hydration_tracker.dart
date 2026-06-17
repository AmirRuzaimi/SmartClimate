import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart'; // Replaced shared_preferences!
import 'session_data.dart';
import 'striped_painter.dart';

class HydrationTracker extends StatefulWidget {
  const HydrationTracker({super.key});

  @override
  State<HydrationTracker> createState() => _HydrationTrackerState();
}

class _HydrationTrackerState extends State<HydrationTracker> {
  double _currentLiters = 0.0;
  final double _goalLiters = 3.0;

  // Using a static document ID for the user's daily record.
  // In a production app, this would be the user's authentic Firebase Auth UID!
  final String _userId = 'Amir';

  @override
  void initState() {
    super.initState();
    _listenToHydrationData();
  }

  // Listens to real-time stream updates from Firestore database clusters
  void _listenToHydrationData() {
    FirebaseFirestore.instance
        .collection('user_wellness')
        .doc(_userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (mounted) {
          setState(() {
            // Read double or default to 0.0 if not yet set
            _currentLiters = (data['hydration_amount'] ?? 0.0).toDouble();
          });
        }
      }
    });
  }

  // Save/Update progress live to Firestore cloud storage
  Future<void> _updateHydrationInFirestore(double newAmount) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_wellness')
          .doc(_userId)
          .set({
        'hydration_amount': newAmount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'userName': _userId,
      }, SetOptions(merge: true)); // Merges so it doesn't overwrite other checklist data fields
    } catch (e) {
      debugPrint("Error updating cloud hydration: $e");
    }
  }

  void _addWater() {
    if (_currentLiters < _goalLiters) {
      double nextAmount = math.min(_currentLiters + 0.25, _goalLiters);
      _updateHydrationInFirestore(nextAmount);
    }
  }

  void _resetWater() {
    _updateHydrationInFirestore(0.0);
  }

  @override
  Widget build(BuildContext context) {
    double progress = _currentLiters / _goalLiters;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hydration Tracker',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _resetWater,
            tooltip: 'Reset Progress',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                "Today's Goal",
                style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.opacity, color: Colors.blue, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '$_goalLiters Liters',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: CustomPaint(
                  size: const Size(220, 220),
                  painter: WaterProgressPainter(progress: progress),
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_currentLiters.toStringAsFixed(1)}L',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '(${(progress * 100).toInt()}%)',
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, color: Colors.orange, size: 30),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "It's hot today!",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            "Drink more water to stay hydrated.",
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildButton(
                text: 'Add 250ml',
                icon: Icons.add,
                onPressed: _addWater,
              ),
              const SizedBox(height: 16),
              _buildButton(
                text: 'View Session Data',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SessionDataPage()),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 50,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: CustomPaint(
          painter: StripedPainter(),
        ),
      ),
    );
  }

  Widget _buildButton({required String text, IconData? icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          foregroundColor: Colors.black,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: const TextStyle(fontSize: 16)),
            if (icon != null) Icon(icon),
          ],
        ),
      ),
    );
  }
}

class WaterProgressPainter extends CustomPainter {
  final double progress;

  WaterProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bgPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const startAngle = 0.75 * math.pi;
    final sweepAngle = 1.5 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    final fillPaint = Paint()..color = Colors.blue.withOpacity(0.1);
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(clipPath);

    final fillHeight = size.height * (1 - progress * 0.75);
    canvas.drawRect(Rect.fromLTRB(0, fillHeight, size.width, size.height), fillPaint);
    canvas.restore();

    const textStyle = TextStyle(color: Colors.black, fontSize: 12);
    _drawText(canvas, "0", Offset(center.dx - radius * 0.8, center.dy + radius * 0.7), textStyle);
    _drawText(canvas, "3.0L", Offset(center.dx + radius * 0.6, center.dy + radius * 0.7), textStyle);
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}