import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../gobal/drawerbar_nisit.dart';
import 'subject_detail_nisit.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class UserNisit extends StatefulWidget {
  @override
  _UserNisitState createState() => _UserNisitState();
}

class _UserNisitState extends State<UserNisit> {
  final List<String> subjects = [];
  final TextEditingController _codeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String currentUserUid;

  @override
  void initState() {
    super.initState();
    currentUserUid = _auth.currentUser!.uid;
    initUserEthereumAddress(context);

    fetchSubjects();
  }

  Future<void> initUserEthereumAddress(BuildContext context) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .get();
      final data = userDoc.data() as Map<String, dynamic>?;
      print('Current User UID: $currentUserUid');
      if (data != null &&
          data.containsKey('ethereumAddress') &&
          data['ethereumAddress'] != null) {
        print('User has Ethereum Address: ${data['ethereumAddress']}');
      } else {
        final url = Uri.parse('http://192.168.1.2:3000/sendEther');
        //final url = Uri.parse('http://10.0.2.2:3000/createEthereumAddress');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': currentUserUid}),
        );

        if (response.statusCode == 200) {
          final responseBody = jsonDecode(response.body);
          final newEthereumAddress = responseBody['ethereumAddress'];

          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserUid)
              .set({
            'ethereumAddress': newEthereumAddress,
            'ethereumPrivateKey': responseBody['ethereumPrivateKey'],
          }, SetOptions(merge: true));

          print('Created and set new Ethereum Address: $newEthereumAddress');

          // แสดง snackbar
          final snackBar = SnackBar(
            content: Text('Ethereum Address ถูกสร้างเสร็จสิ้น!'),
            duration: Duration(seconds: 3),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        } else {
          print('Failed to create Ethereum Address: ${response.body}');
        }
      }
    } catch (error) {
      print('Error during initUserEthereumAddress: $error');
      // TODO: แสดง error message หรือใช้ UI indicator แสดงสถานะ error ใน app ของคุณ
    }
  }

//สร้างฟังก์ชันในการลบวิชา:
  Future<void> _deleteSubject(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .collection('enrolledSubjects')
        .doc(docId)
        .delete();

    // อัพเดท UI
    setState(() {
      subjects.removeWhere((subject) => subject == docId);
    });
  }

  /// ฟังก์ชั่นสำหรับดึงวิชาที่นิสิตเข้าร่วม
  Future<void> fetchSubjects() async {
    var userSubjects = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .collection('enrolledSubjects')
        .get();

    List<String> fetchedSubjects = [];
    for (var doc in userSubjects.docs) {
      fetchedSubjects.add(doc.data()['name'] as String);
    }

    setState(() {
      subjects.addAll(fetchedSubjects);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("วิชาเรียน"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSubject,
          ),
        ],
      ),
      drawer: const DrawerBarNisit(),
      body: _buildSubjectList(),
    );
  }

  Widget _buildSubjectList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .collection('enrolledSubjects')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot doc = snapshot.data!.docs[index];
            Map<String, dynamic> subject = doc.data() as Map<String, dynamic>;
            return _buildSubjectTile(subject, doc.id, context);
          },
        );
      },
    );
  }

  Widget _buildSubjectTile(
      Map<String, dynamic> subject, String docId, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 8,
      color: Color.fromARGB(255, 248, 247, 247),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: Color.fromARGB(255, 124, 124, 123),
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
                builder: (context) => SubjectDetailNisit(
                  userId: currentUserUid,
                  docId: docId,
                  subjectName: subject['name'], // ส่งชื่อวิชา
                  subjectCode: subject['code'], // ส่งรหัสวิชา
                  subjectGroup: subject['group'], // ส่งหมู่เรียน
                  uidTeacher: subject['uidTeacher'],
                ),
              ),
            );
          },
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            'Code: ${subject['code']}, Group: ${subject['group']},',
            style: TextStyle(color: Colors.grey[800]),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red[600], // ปรับสี
            iconSize: 30, // ปรับขนาด
            onPressed: () =>
                _showDeleteConfirmationDialog(context, docId, subject['name']),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, String subjectId, String? subjectName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ยืนยัน'),
          content: Text('คุณต้องการลบวิชา  $subjectName หรือไม่?'),
          actions: <Widget>[
            TextButton(
              child: const Text('ไม่'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('ใช่'),
              onPressed: () {
                _deleteSubject(subjectId);
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  void _addSubject() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('กรอกรหัสเพื่อเข้าร่วมวิชา'),
          content: TextField(
            controller: _codeController,
            decoration: InputDecoration(hintText: "กรอกรหัส"),
          ),
          actions: [
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('เข้าร่วม'),
              onPressed: _processSubjectJoining,
            ),
          ],
        );
      },
    );
  }

  Future<void> _processSubjectJoining() async {
    String code = _codeController.text;
    var query = await FirebaseFirestore.instance
        .collectionGroup('subjects')
        .where('inviteCode', isEqualTo: code)
        .get();

    var userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .get();

    String currentUserName = userData.data()?['Username'];
    String currentUserEmail = userData.data()?['email'];
    String currentstudentId = userData.data()?['studentId'];
    if (query.docs.isNotEmpty) {
      var subjectData = query.docs.first.data();
      String subjectName = subjectData['name'];
      bool isApproved = subjectData['students'] != null &&
          subjectData['students'].contains(currentUserUid);

      if (isApproved) {
        setState(() {
          subjects.add(subjectName);
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserUid)
            .collection('subjects')
            .doc(subjectName)
            .set(subjectData);
      } else {
        await FirebaseFirestore.instance
            .doc(query.docs.first.reference.path)
            .update({
          'pendingStudents': FieldValue.arrayUnion([
            {
              'uid': currentUserUid, //ส่งค่าdoc.idของนิสิต
              'name': currentUserName, //ส่งค่า Username
              'email': currentUserEmail, //ส่งค่าemail
              'studentId': currentstudentId, // ส่งค่า studentId
            }
          ])
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("รอคำอนุมัติ"),
        ));
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("รหัสไม่ถูกต้อง!"),
      ));
      Navigator.of(context).pop();
    }
  }
}
