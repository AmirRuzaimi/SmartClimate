import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'striped_painter.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "anonymous_user";
  bool _isLoading = true;

  // Local state container for reminders mapping
  final List<Map<String, dynamic>> _reminders = [
    {'key': 'hydration', 'title': 'Hydration Reminder', 'subtitle': 'Every 2 Hours', 'enabled': true, 'icon': Icons.opacity},
    {'key': 'sunscreen', 'title': 'Sunscreen Reminder', 'subtitle': '9:00 AM', 'enabled': true, 'icon': Icons.wb_sunny_outlined},
    {'key': 'heatwave', 'title': 'Heatwave Alert', 'subtitle': 'As needed', 'enabled': true, 'icon': Icons.thermostat},
    {'key': 'outdoor', 'title': 'Outdoor Activity', 'subtitle': '1:00 PM', 'enabled': false, 'icon': Icons.directions_run},
    {'key': 'sleep', 'title': 'Sleep Reminder', 'subtitle': '11:00 PM', 'enabled': true, 'icon': Icons.nightlight_round},
  ];

  String _selectedSound = 'Soft Bell';

  @override
  void initState() {
    super.initState();
    _loadUserReminderSettings();
  }

  // ─── LOAD DATA FROM CLOUD ──────────────────────────────────────────────────
  Future<void> _loadUserReminderSettings() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;

        // Retrieve settings block if existing
        if (data.containsKey('reminder_settings')) {
          final settings = data['reminder_settings'] as Map<String, dynamic>;

          if (settings.containsKey('notificationSound')) {
            _selectedSound = settings['notificationSound'] ?? 'Soft Bell';
          }

          // Distribute enabled toggle values back down to array items matching keys
          for (var reminder in _reminders) {
            final String key = reminder['key'];
            if (settings.containsKey(key)) {
              reminder['enabled'] = settings[key] ?? reminder['enabled'];
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error pulling configurations: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── COMMIT DATA TO CLOUD ──────────────────────────────────────────────────
  Future<void> _saveUserReminderSettings() async {
    // Show a small loading overlay or snackbar during network transaction
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving preferences...'), duration: Duration(milliseconds: 400)),
    );

    try {
      // Package payload data structure dynamically
      final Map<String, dynamic> settingsPayload = {
        'notificationSound': _selectedSound,
      };

      for (var reminder in _reminders) {
        settingsPayload[reminder['key']] = reminder['enabled'];
      }

      // Merge payload fields directly onto primary profile block
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .set({
        'reminder_settings': settingsPayload,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully! 🎉'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving configurations: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Reminder Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.orange)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reminders.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 50),
                itemBuilder: (context, index) {
                  final item = _reminders[index];
                  return ListTile(
                    leading: Icon(item['icon'], color: Colors.black87),
                    title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(item['subtitle'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: Switch(
                      value: item['enabled'],
                      onChanged: (val) {
                        setState(() {
                          _reminders[index]['enabled'] = val;
                        });
                      },
                      activeThumbColor: Colors.black87,
                      activeTrackColor: Colors.black45,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notification Sound', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSound,
                        isExpanded: true,
                        items: ['Soft Bell', 'Classic Chime', 'Nature Birds']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSound = val!;
                          });
                        },
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveUserReminderSettings, // Hooked up the save function!
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 50,
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
        child: CustomPaint(painter: StripedPainter()),
      ),
    );
  }
}