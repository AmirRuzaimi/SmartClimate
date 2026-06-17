import 'package:flutter/material.dart';

class SessionDataPage extends StatelessWidget {
  const SessionDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDataCard(
            'Session Duration',
            '12m 45s',
            Icons.timer_outlined,
            Colors.blue.shade100,
          ),
          const SizedBox(height: 16),
          _buildDataCard(
            'Alerts Received',
            '3',
            Icons.notifications_active_outlined,
            Colors.red.shade100,
          ),
          const SizedBox(height: 16),
          _buildDataCard(
            'Location Updates',
            '24',
            Icons.location_on_outlined,
            Colors.green.shade100,
          ),
          const SizedBox(height: 16),
          _buildDataCard(
            'Community Reports',
            '5',
            Icons.chat_bubble_outline_rounded,
            Colors.orange.shade100,
          ),
          const SizedBox(height: 24),
          const Text(
            'ACTIVITY LOG',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildLogItem('System Initialized', '10:00 AM'),
          _buildLogItem('Heat Alert Triggered (Kota Bharu)', '10:05 AM'),
          _buildLogItem('User Reported Temperature (37°C)', '10:15 AM'),
          _buildLogItem('Cooling Center Search Performed', '10:22 AM'),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(String message, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}