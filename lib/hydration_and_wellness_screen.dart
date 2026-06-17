import 'package:flutter/material.dart';
import 'hydration_tracker.dart';
import 'wellness_screen.dart'; // Loads your updated dynamic CRUD checklist!
import 'reminder_screen.dart';
import 'striped_painter.dart';

class HydrationAndWellnessScreen extends StatelessWidget {
  const HydrationAndWellnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Hydration and Wellness',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildOptionCard(
              context,
              title: 'Hydration Tracker',
              icon: Icons.water_drop_rounded, // Made it a bit sleeker
              color: Colors.blue.shade600,
              destination: const HydrationTracker(),
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              title: 'Daily Wellness Checklist', // Matches your new page title!
              icon: Icons.wb_sunny_rounded,
              color: Colors.orange.shade700,
              destination: const WellnessScreen(), // REMOVED 'const' here so it compiles cleanly with dynamic Firebase IDs
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              title: 'Reminder Settings',
              icon: Icons.notifications_active_outlined,
              color: Colors.blueGrey,
              destination: const ReminderScreen(),
            ),
          ],
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

  Widget _buildOptionCard(BuildContext context,
      {required String title,
        required IconData icon,
        required Color color,
        required Widget destination}) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade200, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Slightly rounder to match the profile card styling
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}