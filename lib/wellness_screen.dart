import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'striped_painter.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "anonymous_user";
  final TextEditingController _taskController = TextEditingController();

  final List<String> _recommendedTasks = [
    'Drink 8 glasses of water',
    'Apply sunscreen (SPF 30+)',
    'Wear hat / sunglasses',
    'Check local weather forecast',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrapDefaultTasksIfEmpty();
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  // ─── CLOUD BOOTSTRAPPER ────────────────────────────────────────────────────
  Future<void> _bootstrapDefaultTasksIfEmpty() async {
    try {
      final subcollectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('wellness_tasks');

      final snapshot = await subcollectionRef.get();

      if (snapshot.docs.isEmpty) {
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var taskTitle in _recommendedTasks) {
          final docRef = subcollectionRef.doc();
          batch.set(docRef, {
            'title': taskTitle,
            'completed': false,
            'createdAt': FieldValue.serverTimestamp(),
            'isCustom': false,
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error bootstrapping standard wellness recommendations: $e");
    }
  }

  // ─── TASK OVERLAY UTILITY (ADD / EDIT) ─────────────────────────────────────
  void _showTaskDialog({String? docId, String? currentTitle}) {
    _taskController.text = currentTitle ?? "";
    final bool isEditing = docId != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEditing ? "Edit Wellness Task" : "Add Custom Task",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _taskController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: "e.g., Avoid outdoor activities from 12PM-3PM",
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange.shade700)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final String taskText = _taskController.text.trim();
              if (taskText.isEmpty) return;

              final userRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUid)
                  .collection('wellness_tasks');

              if (isEditing) {
                await userRef.doc(docId).update({'title': taskText});
              } else {
                await userRef.add({
                  'title': taskText,
                  'completed': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'isCustom': true,
                });
              }

              // After adding or editing, evaluate state checklist goals
              _checkAndEvaluateProgress();

              if (mounted) {
                Navigator.pop(context);
                _taskController.clear();
              }
            },
            child: Text(isEditing ? "Update" : "Add", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── ACTIVE TRANSACTION ENGINE: RE-CALCULATES BADGES ON PROGRESS CHANGES ───
  Future<void> _checkAndEvaluateProgress() async {
    try {
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('wellness_tasks')
          .get();

      final taskDocs = tasksSnapshot.docs;
      final int total = taskDocs.length;
      final int completed = taskDocs.where((doc) => doc.data()['completed'] == true).length;

      if (total == 0) return;

      final DocumentReference userProfileDoc =
      FirebaseFirestore.instance.collection('users').doc(_currentUid);

      if (completed == total) {
        // Grant achievements if 100% complete
        await userProfileDoc.set({
          'achievements': FieldValue.arrayUnion(['Hydration Master', 'Climate Resilient']),
          'lastCompletedStreak': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Strip achievements if user unchecks items below 100%
        await userProfileDoc.set({
          'achievements': FieldValue.arrayRemove(['Hydration Master', 'Climate Resilient']),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error updating verification achievements tokens: $e");
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
          'Daily Wellness Checklist',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: Colors.orange.shade800, size: 26),
            tooltip: 'Add Custom Task',
            onPressed: () => _showTaskDialog(),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .collection('wellness_tasks')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error fetching wellness metrics."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.orange)));
          }

          final taskDocs = snapshot.data?.docs ?? [];
          final int totalTasks = taskDocs.length;
          final int completedCount = taskDocs.where((doc) => (doc.data() as Map<String, dynamic>)['completed'] == true).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.orange.withOpacity(0.02),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '“The secret to success is found in your daily routine!” - John C M',
                          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.wb_sunny_outlined, color: Colors.orange.shade700, size: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Tasks",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (totalTasks > 0)
                      Text(
                        "$completedCount of $totalTasks Completed",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                if (taskDocs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        "No tasks registered.\nTap the top right icon to append custom health reminders!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),

                ...taskDocs.map((doc) {
                  final String docId = doc.id;
                  final task = doc.data() as Map<String, dynamic>;
                  final bool isCompleted = task['completed'] ?? false;
                  final String title = task['title'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Dismissible(
                      key: Key(docId),
                      background: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.delete_forever, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(_currentUid)
                            .collection('wellness_tasks')
                            .doc(docId)
                            .delete();

                        // Re-evaluate achievements array list on item removal
                        _checkAndEvaluateProgress();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                          color: isCompleted ? Colors.grey.shade50 : Colors.white,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: InkWell(
                            onTap: () async {
                              // 1. Update check state in subcollection
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_currentUid)
                                  .collection('wellness_tasks')
                                  .doc(docId)
                                  .update({'completed': !isCompleted});

                              // 2. Safely trigger badge validation logic out of the layout draw line!
                              _checkAndEvaluateProgress();
                            },
                            child: Icon(
                              isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                              color: isCompleted ? Colors.orange.shade700 : Colors.grey,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              color: isCompleted ? Colors.grey : Colors.black87,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                                onPressed: () => _showTaskDialog(docId: docId, currentTitle: title),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // ─── DYNAMIC METRIC PROGRESS CARD ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6, offset: const Offset(0, 3))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Resilience Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            totalTasks == 0 ? "0%" : "${((completedCount / totalTasks) * 100).toStringAsFixed(0)}%",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: totalTasks == 0 ? 0.0 : (completedCount / totalTasks),
                          backgroundColor: Colors.grey[100],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        height: 50,
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
        child: CustomPaint(painter: StripedPainter()),
      ),
    );
  }
}