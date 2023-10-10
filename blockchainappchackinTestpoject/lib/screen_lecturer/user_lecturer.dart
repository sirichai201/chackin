import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../gobal/drawerbar_lecturer.dart';
import 'subject_detail_lecturer.dart'; // Custom drawer imported
import 'package:uuid/uuid.dart';

class UserLecturer extends StatefulWidget {
  @override
  _UserLecturerState createState() => _UserLecturerState();
}

class _UserLecturerState extends State<UserLecturer> {
  late final String userId; // Declare the userId variable

  String generateInviteCode() {
    var uuid = Uuid();
    return uuid.v4().substring(0, 6); // สร้างรหัสเชิญ 6 ตัวอักษร
  }

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid; // Initialize userId
  }

  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, String docId) async {
    // Show a dialog box to confirm deletion
    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: const Text('คุณต้องการลบรายวิชานี้ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ลบ'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('subjects')
          .doc(docId)
          .delete(); // Delete only the selected subject
    }
  }

  Future<void> _addSubject() async {
    TextEditingController codeController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    TextEditingController groupController = TextEditingController();
    TextEditingController yearController = TextEditingController();
    String? selectedTerm;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เพิ่มรายวิชาใหม่'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: 'รหัสวิชา'),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'ชื่อรายวิชา'),
                  ),
                  TextField(
                    controller: groupController,
                    decoration: const InputDecoration(labelText: 'หมู่เรียน'),
                  ),
                  TextField(
                    controller: yearController,
                    decoration: InputDecoration(
                      labelText: 'ปีการศึกษา',
                      hintText:
                          'กรุณาใส่เป็น คศ เช่น 2023', // บรรทัดนี้เป็นการเพิ่มข้อความบอก
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButton<String>(
                    value: selectedTerm,
                    items: ['1', '2']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text('เทอม $value'),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedTerm = newValue;
                      });
                    },
                    hint: Text('กรุณาเลือกเทอม'),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () async {
                String inviteCode = generateInviteCode();
                if (codeController.text.isNotEmpty &&
                    nameController.text.isNotEmpty &&
                    groupController.text.isNotEmpty &&
                    yearController.text.isNotEmpty &&
                    selectedTerm != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('subjects')
                      .add({
                    'code': codeController.text.trim(),
                    'name': nameController.text.trim(),
                    'group': groupController.text.trim(),
                    'year': yearController.text.trim(),
                    'term': selectedTerm,
                    'inviteCode': inviteCode,
                    'students': [],
                    'pendingStudents': [],
                    'uidTeacher': userId
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('เพิ่ม'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('วิชาเรียน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSubject,
          ),
        ],
      ),
      drawer: DrawerbarLecturer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('subjects')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot doc = snapshot.data!.docs[index];
              Map<String, dynamic> subject = doc.data() as Map<String, dynamic>;
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                elevation: 8,
                color: Color.fromARGB(255, 241, 240, 240),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: Color.fromARGB(255, 145, 145, 143),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubjectDetail(
                            userId: userId,
                            docId: doc.id,
                          ),
                        ),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    leading: Icon(
                      Icons.book, // icon แสดงถึงวิชา
                      color: Colors.blue[600],
                      size: 30, // ขนาดของ icon
                    ),
                    title: Text(
                      subject['name'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20, // ปรับขนาด
                        color: Colors.blue[700], // ปรับสี
                      ),
                    ),
                    subtitle: Text(
                      'Code: ${subject['code']}, Group: ${subject['group']}, Invite Code: ${subject['inviteCode']}',
                      style: TextStyle(
                        color: Colors.grey[700], // ปรับสี
                        fontSize: 16, // ปรับขนาด
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red[600], // ปรับสี
                      iconSize: 30, // ปรับขนาด
                      onPressed: () =>
                          _showDeleteConfirmationDialog(context, doc.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
