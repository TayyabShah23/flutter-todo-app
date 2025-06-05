import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddTask extends StatefulWidget {
  const AddTask({super.key});

  @override
  State<AddTask> createState() => _AddTaskState();
}

class _AddTaskState extends State<AddTask> {
  final TextEditingController _taskController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedTaskId;
  String _schedule = "Today";

  void _createOrUpdateTask(String schedule) async {
    final user = _auth.currentUser;
    if (user == null || _taskController.text.trim().isEmpty) return;

    final data = {
      "task": _taskController.text.trim(),
      "schedule": schedule,
      "userId": user.uid,
      "status": "pending",
      "timestamp": Timestamp.now(), // Immediate timestamp instead of serverTimestamp
    };

    if (_selectedTaskId == null) {
      await _firestore.collection("Tasks").add(data);
      _taskController.clear();
      Navigator.pop(context);
    } else {
      await _firestore.collection("Tasks").doc(_selectedTaskId).update({
        "task": _taskController.text.trim(),
        "schedule": schedule,
      });
      _selectedTaskId = null;
    }
  }

  void _showTaskDialog([String? taskId, String? taskText, String? schedule]) {
    String dialogSchedule = schedule ?? "Today";
    _taskController.text = taskText ?? "";
    _selectedTaskId = taskId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFFdce5ff),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              taskId == null ? "Add Task" : "Update Task",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _taskController,
                  decoration: const InputDecoration(
                    hintText: "Enter task",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: dialogSchedule,
                  decoration: const InputDecoration(labelText: "Schedule"),
                  items: ["Today", "Tomorrow"].map((val) {
                    return DropdownMenuItem(value: val, child: Text(val));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setStateDialog(() {
                        dialogSchedule = val;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1f0385)),
                onPressed: () => _createOrUpdateTask(dialogSchedule),
                child: Text(taskId == null ? "Add" : "Update", style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  void _markAsDone(String id) {
    _firestore.collection("Tasks").doc(id).update({"status": "done"});
  }

  void _deleteTask(String id) {
    _firestore.collection("Tasks").doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1f0385),
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1f0385), Colors.lightBlueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header and dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Your Tasks",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _schedule,
                  dropdownColor: Colors.white,
                  underline: Container(),
                  items: ["Today", "Tomorrow"].map((val) {
                    return DropdownMenuItem(value: val, child: Text(val));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _schedule = val;
                      });
                    }
                  },
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Task list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Tasks')
                    .where('userId', isEqualTo: user?.uid)
                    .where('schedule', isEqualTo: _schedule)
                    .where('status', isEqualTo: 'pending')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No $_schedule tasks yet",
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (ctx, index) {
                      final doc = docs[index];
                      final task = doc['task'] ?? "No Task";
                      final schedule = doc['schedule'] ?? "N/A";

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(task, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text("Scheduled: $schedule"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.done, color: Colors.green),
                                onPressed: () => _markAsDone(doc.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _showTaskDialog(doc.id, task, schedule),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTask(doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }
}
