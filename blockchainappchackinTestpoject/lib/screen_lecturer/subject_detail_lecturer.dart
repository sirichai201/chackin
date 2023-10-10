import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chackin.dart';

class SubjectDetail extends StatefulWidget {
  final String userId;
  final String docId;

  SubjectDetail({required this.userId, required this.docId, Key? key})
      : super(key: key);

  @override
  _SubjectDetailState createState() => _SubjectDetailState();
}

class _SubjectDetailState extends State<SubjectDetail> {
  final CollectionReference subjects =
      FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCheckInPage,
        child: Icon(Icons.check),
        backgroundColor: Colors.green,
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: StreamBuilder<DocumentSnapshot>(
        stream: subjects
            .doc(widget.userId)
            .collection('subjects')
            .doc(widget.docId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text("Loading...");
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Text("Error loading data");
          }
          Map<String, dynamic> subject =
              snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // กำหนดขนาดขั้นต่ำของ Column
            children: [
              Text(subject['name'] ?? '', style: TextStyle(fontSize: 18)),
              SizedBox(height: 4),
              Text(
                'Code: ${subject['code']}, Group: ${subject['group']}',
                style: TextStyle(fontSize: 14),
              ),
            ],
          );
        },
      ),
    );
  }

  Padding _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: subjects
            .doc(widget.userId)
            .collection('subjects')
            .doc(widget.docId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Text("Error loading data");
          }
          Map<String, dynamic> subject =
              snapshot.data!.data() as Map<String, dynamic>;

          List<dynamic> pendingStudents = subject['pendingStudents'] ?? [];
          List<dynamic> approvedStudents = subject['students'] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _inviteCodeDisplay(subject),
              SizedBox(height: 16.0),
              _pendingStudentsDropdown(pendingStudents),
              SizedBox(height: 16.0),
              _approvedStudentsDropdown(approvedStudents),
            ],
          );
        },
      ),
    );
  }

  Container _inviteCodeDisplay(Map<String, dynamic> subject) {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent),
      ),
      child: Text('Invite Code: ${subject['inviteCode']}'),
    );
  }

  Container _pendingStudentsDropdown(List<dynamic> pendingStudents) {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: DropdownButton<dynamic>(
        hint: Text('Pending Students:'),
        onChanged: (value) {},
        items: pendingStudents.map((student) {
          return DropdownMenuItem<dynamic>(
            value: student,
            child: Row(
              children: [
                Text('${student['name']} (${student['email']})'),
                IconButton(
                  icon: Icon(Icons.check, color: Colors.green),
                  onPressed: () => approveStudent(
                      student['uid'], student['name'], student['email']),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red),
                  onPressed: () => rejectStudent(student['uid']),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Container _approvedStudentsDropdown(List<dynamic> approvedStudents) {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: DropdownButton<dynamic>(
        hint: Text('Approved Students:'),
        onChanged: (value) {},
        items: approvedStudents.map((student) {
          return DropdownMenuItem<dynamic>(
            value: student,
            child: Text('${student['name']} (${student['email']})'),
          );
        }).toList(),
      ),
    );
  }

  Future<void> approveStudent(
      String studentUid, String studentName, String studentEmail) async {
    DocumentSnapshot subjectDoc = await subjects
        .doc(widget.userId)
        .collection('subjects')
        .doc(widget.docId)
        .get();
    Map<String, dynamic> subject = subjectDoc.data() as Map<String, dynamic>;

    List<dynamic> pendingStudents = subject['pendingStudents'] ?? [];

    await subjects
        .doc(widget.userId)
        .collection('subjects')
        .doc(widget.docId)
        .update({
      'students': FieldValue.arrayUnion(pendingStudents), // ย้ายทั้งหมดมาที่นี่
      'pendingStudents':
          FieldValue.arrayRemove(pendingStudents) // ลบทั้งหมดออกจากนี่
    });

    // ต้องทำ Loop ต่อไปนี้เพื่ออัพเดทข้อมูลใน collection 'enrolledSubjects' ของแต่ละนิสิต
    for (var student in pendingStudents) {
      var studentData = student as Map<String, dynamic>;
      await subjects
          .doc(studentData['uid'])
          .collection('enrolledSubjects')
          .doc(widget.docId)
          .set({
        'name': subject['name'],
        'code': subject['code'],
        'group': subject['group'],
        'uidTeacher': widget.userId,
        'year': subject['year'], // ค่าของ 'year' จาก object subject
        'term': subject['term'], // ค่าของ 'term' จาก object subject
      });
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('ได้ยืนยันเรียบร้อยแล้ว')));
  }

  Future<void> rejectStudent(String studentUid) async {
    DocumentSnapshot subjectDoc = await subjects
        .doc(widget.userId)
        .collection('subjects')
        .doc(widget.docId)
        .get();
    Map<String, dynamic> subject = subjectDoc.data() as Map<String, dynamic>;

    List<dynamic> pendingStudents = subject['pendingStudents'] ?? [];
    var studentToRemove;

    for (var student in pendingStudents) {
      var studentData = student as Map<String, dynamic>;
      if (studentData['uid'] == studentUid) {
        studentToRemove = studentData;
        break;
      }
    }

    if (studentToRemove != null) {
      await subjects
          .doc(widget.userId)
          .collection('subjects')
          .doc(widget.docId)
          .update({
        'pendingStudents': FieldValue.arrayRemove([studentToRemove])
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ลบเรียบร้อยแล้ว')));
    }
  }

  void _navigateToCheckInPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (context) =>
              CheckInPage(docId: widget.docId, userId: widget.userId)),
    );
  }
}
