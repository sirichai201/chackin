import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'user_lecturer.dart';

class History extends StatefulWidget {
  @override
  _HistoryState createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  final userDocId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> subjectsList = [];
  late DateTime selectedDate;
  String selectedYear = '';
  String selectedTerm = '';
  String selectedSubject = '';
  late List<String> uniqueYears;
  late List<String> uniqueTerms;
  late List<String> uniqueSubjects;
  final subjectController = TextEditingController();
  List<Map<String, dynamic>> attendanceList = []; // For storing attendance data
  String? statusMessage;

  @override
  void initState() {
    super.initState();
    loadSubjects();
    uniqueYears = [];
    uniqueTerms = [];
    uniqueSubjects = [];
    selectedDate = DateTime.now();
  }

  Future<void> _markAbsentStudents(
      String formattedSelectedDate, String selectedSubjectDocId) async {
    final subjects = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('subjects');
    final subjectDoc = subjects.doc(selectedSubjectDocId);
    // ดึงรายชื่อนิสิตทั้งหมด
    final studentsList = await subjectDoc.get().then((doc) {
      if (doc.exists) {
        return List<Map<String, dynamic>>.from(doc['students']);
      }
      return [];
    });

    final studentIds =
        studentsList.map((student) => student['studentId']).toList();

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final scheduleSnapshot = await transaction.get(subjectDoc
          .collection('attendanceSchedules')
          .doc(formattedSelectedDate));

      if (!scheduleSnapshot.exists) {
        // Handle error: the document doesn't exist.
        return;
      }

      final currentCheckedStudents = List<Map<String, dynamic>>.from(
          scheduleSnapshot.data()?['studentsChecked'] ?? []);

      final absentStudents = studentIds
          .where((id) => !currentCheckedStudents
              .any((student) => student['studentId'] == id))
          .toList();

      for (var absentStudentId in absentStudents) {
        var studentData = studentsList.firstWhere(
            (s) => s['studentId'] == absentStudentId,
            orElse: () => <String, dynamic>{});

        if (!studentData.containsKey('studentId')) continue;

        var studentName = studentData['name'];
        var studentUid = studentData['uid'];

        // ตรวจสอบว่านิสิตนั้นถูกเพิ่มเข้าไปใน studentsChecked หรือยัง
        bool isStudentAlreadyChecked = currentCheckedStudents
            .any((student) => student['studentId'] == absentStudentId);

        // ถ้ายังไม่ถูกเพิ่มเข้าไป จึงทำการเพิ่ม
        if (!isStudentAlreadyChecked) {
          final absentStudentData = {
            'studentId': absentStudentId,
            'name': studentName,
            'status': 'absent',
            'time': Timestamp.now(),
            'uid': studentUid,
          };

          currentCheckedStudents.add(absentStudentData);
          // อัปเดตข้อมูลเข้าฝั่งนิสิต
          await _updateStudentRecord(
              absentStudentData, studentUid, selectedSubjectDocId);
        }
      }

      // ทำการอัพเดทข้อมูลลงในฐานข้อมูลโดยใช้ transaction
      transaction.update(
          subjectDoc
              .collection('attendanceSchedules')
              .doc(formattedSelectedDate),
          {'studentsChecked': currentCheckedStudents});
    });
  }

  Future<void> _updateStudentRecord(Map<String, dynamic> checkInData,
      String studentUid, String selectedSubjectDocId) async {
    final studentSubjectRef = _firestore
        .collection('users')
        .doc(studentUid) // ใช้ uid ของนิสิตเป็น document ID
        .collection('enrolledSubjects')
        .doc(selectedSubjectDocId);

    final studentAttendanceScheduleRef = studentSubjectRef
        .collection('attendanceSchedulesRecords')
        .doc(DateTime.now().toLocal().toString().split(' ')[0]);

    // ทำการเช็คว่ามี document นี้หรือยัง ถ้ายังก็สร้าง
    if (!(await studentAttendanceScheduleRef.get()).exists) {
      await studentAttendanceScheduleRef.set({
        // เพิ่มข้อมูลเบื้องต้นที่คุณต้องการจะเก็บไว้
      });
    }

    // อ่านข้อมูลที่มีอยู่
    DocumentSnapshot snapshot = await studentAttendanceScheduleRef.get();
    List existingData;
    if (snapshot.exists && snapshot.data() != null) {
      existingData =
          (snapshot.data() as Map<String, dynamic>)['studentsCheckedRecords'] ??
              [];
    } else {
      existingData = [];
    }

    // ตรวจสอบว่าข้อมูลนั้นยังไม่มีอยู่
    bool alreadyExists = existingData
        .any((data) => data['studentId'] == checkInData['studentId']);

    // ถ้าไม่มี, ค่อยทำการบันทึกข้อมูล
    if (!alreadyExists) {
      await studentAttendanceScheduleRef.update({
        'studentsCheckedRecords': FieldValue.arrayUnion([checkInData])
      });
    }
  }

  Future<void> loadSubjects() async {
    final subjectsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('subjects');
    final snapshot = await subjectsRef.get();

    Set<String> years = {};
    Set<String> terms = {};
    Set<String> subjects = {};

    subjectsList = snapshot.docs
        .map((doc) => {'docId': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();

    subjectsList.forEach((subject) {
      years.add(subject['year'] ?? '');
      terms.add(subject['term'] ?? '');
      subjects.add(subject['name'] ?? '');
    });

    uniqueYears = years.toList(); // Set instance variables directly
    uniqueTerms = terms.toList();
    uniqueSubjects = subjects.toList();

    if (uniqueYears.isNotEmpty &&
        uniqueTerms.isNotEmpty &&
        uniqueSubjects.isNotEmpty) {
      setState(() {
        selectedYear = uniqueYears[0];
        selectedTerm = uniqueTerms[0];
        selectedSubject = uniqueSubjects[0];
      });
    }
  }

  FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // ถ้ายังไม่มีการประกาศ
  void loadAttendanceSchedules() async {
    String formattedSelectedDate =
        DateFormat('yyyy-MM-dd').format(selectedDate);

    final subjectQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('subjects')
        .where('name', isEqualTo: selectedSubject)
        .where('term', isEqualTo: selectedTerm);

    final subjectQuerySnapshot = await subjectQuery.get();

    if (subjectQuerySnapshot.docs.isEmpty) {
      setState(() {
        statusMessage = 'ไม่มีเทอมที่เลือก';
        attendanceList = [];
      });
      return;
    }

    final selectedSubjectDocId = subjectQuerySnapshot.docs.first.id;
    final attendanceDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('subjects')
        .doc(selectedSubjectDocId)
        .collection('attendanceSchedules')
        .doc(formattedSelectedDate);

    final docSnapshot = await attendanceDocRef.get();

    if (!docSnapshot.exists) {
      print('No attendance data found for $formattedSelectedDate');
      setState(() {
        attendanceList = [];
      });
      return;
    }

    final endDate =
        (docSnapshot.data() as Map<String, dynamic>)['endDate'] as Timestamp;

    // Check if current time is before the end date
    if (DateTime.now().isBefore(endDate.toDate())) {
      // If it's before end time, show the dialog.
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('ยังไม่สามารถตรวจสอบได้!'),
            content: Text('คุณไม่สามารถตรวจสอบได้จนกว่าเวลาเช็คชื่อจะหมด.'),
            actions: <Widget>[
              TextButton(
                child: Text('ตกลง'),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
              ),
            ],
          );
        },
      );
      return; // Return so that the rest of the function doesn't execute.
    }

    // If it's after the end time, mark the absent students as absent.
    await _markAbsentStudents(formattedSelectedDate, selectedSubjectDocId);

    final data = docSnapshot.data() as Map<String, dynamic>;
    final studentsChecked = (data['studentsChecked'] as List<dynamic>?) ?? [];

    setState(() {
      attendanceList = studentsChecked.map((student) {
        final studentMap = student as Map<String, dynamic>;
        final status = studentMap['status'] ?? 'unknown';
        final time = studentMap['time'];
        final studentId = studentMap['studentId'] ?? 'unknown student';
        final name = studentMap['name'] ?? 'unknown name';
        return {
          'status': status,
          'time': time,
          'studentId': studentId,
          'name': name,
        };
      }).toList();
      statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => UserLecturer()));
            }),
        title: const Text('ประวัติการเข้าเรียน'),
      ),
      body: subjectsList
              .isEmpty // ถ้า subjectsList ว่าง ให้แสดง loading indicator
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // ถ้า subjectsList มีข้อมูล ให้แสดงรายการ widgets
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButton<String>(
                      value: selectedYear.isNotEmpty ? selectedYear : null,
                      items: uniqueYears.map((year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today),
                              SizedBox(width: 50),
                              Text(year),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedYear = newValue ?? '';

                          // เมื่อเลือกปี ให้รับเดือนและวันจาก selectedDate และปีจาก selectedYear
                          selectedDate = DateTime(int.parse(selectedYear),
                              selectedDate.month, selectedDate.day);
                        });
                      },
                    ),
                    DropdownButton<String>(
                      value: selectedTerm.isNotEmpty ? selectedTerm : null,
                      items: uniqueTerms.map((term) {
                        return DropdownMenuItem<String>(
                          value: term,
                          child: Row(
                            children: [
                              Icon(Icons.format_list_numbered),
                              SizedBox(width: 50),
                              Text(term),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedTerm = newValue ?? '';
                        });
                      },
                    ),
                    DropdownButton<String>(
                      value:
                          selectedSubject.isNotEmpty ? selectedSubject : null,
                      items: uniqueSubjects.map((subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Row(
                            children: [
                              Icon(Icons.book),
                              SizedBox(width: 50),
                              Text(subject),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSubject = newValue ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: Container(
                        margin: const EdgeInsets.only(
                            right: 5.0), // เพิ่มระยะห่างด้านขวาของไอคอน
                        child: const Icon(Icons.date_range),
                      ),
                      title: TextButton(
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null && pickedDate != selectedDate)
                            setState(() {
                              selectedDate = pickedDate;
                            });
                        },
                        child: Text(
                          "วันที่เลือก: ${selectedDate.toLocal().toString().split(' ')[0]}",
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (subjectsList.isNotEmpty) {
                          loadAttendanceSchedules();
                        }
                      },
                      child: const Text('ยืนยัน'),
                    ),

                    const SizedBox(height: 20),
                    // Count summaries
                    Text(
                        'นิสิตมาเรียน: ${attendanceList.where((item) => item['status'] == 'attended').length} คน'),
                    Text(
                        'นิสิตขาดเรียน: ${attendanceList.where((item) => item['status'] == 'absent').length} คน'),
                    Text(
                        'นิสิตลา: ${attendanceList.where((item) => item['status'] == 'leave').length} คน'),
                    const SizedBox(height: 20),
                    ...[
                      if (statusMessage != null) ...[
                        Center(child: Text(statusMessage!))
                      ] else if (attendanceList.isEmpty) ...[
                        Center(
                            child: Text(
                                'ไม่มีข้อมูลนิสิตในวันที่ ${selectedDate.toLocal().toString().split(' ')[0]}'))
                      ] else ...[
                        ...attendanceList.map((attendance) {
                          print(
                              'Building Card for ${attendance['studentId'] ?? 'unknown student'}');
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          'ชื่อ: ${attendance['name'] ?? 'ไม่มีข้อมูล'}'),
                                      Text(
                                          'รหัสนิสิต: ${attendance['studentId'] ?? 'ไม่มีข้อมูล'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 8.0),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          'สถานะ: ${attendance['status'] ?? 'ไม่มีข้อมูล'}'),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 8.0,
                                    width: 20,
                                  ),
                                  Text(
                                      'เวลา: ${_formatTimestamp(attendance['time'] as Timestamp)}'),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

String _formatTimestamp(Timestamp timestamp) {
  final datetime = timestamp.toDate();
  final formatter = DateFormat('yyyy-MM-dd HH:mm'); // adjust format as needed
  return formatter.format(datetime);
}
