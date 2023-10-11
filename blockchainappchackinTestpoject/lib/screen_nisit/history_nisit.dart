import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'user_nisit.dart';

class HistoryNisit extends StatefulWidget {
  @override
  _HistoryNisitState createState() => _HistoryNisitState();
}

class _HistoryNisitState extends State<HistoryNisit> {
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

  Future<void> loadSubjects() async {
    final subjectsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('enrolledSubjects');
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

  void loadAttendanceSchedules() async {
    String formattedSelectedDate =
        DateFormat('yyyy-MM-dd').format(selectedDate);

    // ขั้นตอนที่ 1: ดึง document ของวิชา
    final subjectQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('enrolledSubjects')
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

    final selectedenrolledSubjectsDocId = subjectQuerySnapshot.docs.first.id;

    // ขั้นตอนที่ 2: ดึงข้อมูลการเข้าเรียน
    final attendanceDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('enrolledSubjects')
        .doc(selectedenrolledSubjectsDocId)
        .collection('attendanceSchedulesRecords')
        .doc(formattedSelectedDate);

    final docSnapshot = await attendanceDocRef.get();
    if (!docSnapshot.exists) {
      print('No attendance data found for $formattedSelectedDate');
      setState(() {
        attendanceList = [];
      });
      return;
    }
    final data = docSnapshot.data() as Map<String, dynamic>;
    final studentsCheckedRecords =
        (data['studentsCheckedRecords'] as List<dynamic>?) ?? [];
    // Use setState to rebuild the widget with the new attendance list.
    setState(() {
      attendanceList = studentsCheckedRecords.map((student) {
        final studentMap = student as Map<String, dynamic>;
        final status = studentMap['status'] ?? 'unknown';
        final time = studentMap['time'];
        final studentId = studentMap['studentId'] ?? 'unknown student';
        final name = studentMap['name'] ?? 'unknown name';
        final balanceInEther =
            studentMap['balanceInEther'] ?? 'unknown balance';
        final rewardAmount = studentMap['rewardAmount'] ?? 'unknown reward';
        return {
          'status': status,
          'time': time,
          'studentId': studentId,
          'name': name,
          'balanceInEther': balanceInEther, // Add this
          'rewardAmount': rewardAmount, // And this
        };
      }).toList();

      print('Loaded ${attendanceList.length} attendances');
      print('Attendance List: $attendanceList');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => UserNisit()));
            }),
        title: const Text('ประวัติการเข้าเรียน'),
      ),
      body: subjectsList
              .isEmpty // ถ้า subjectsList ว่าง ให้แสดง loading indicator
          ? const Center(child: CircularProgressIndicator())
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
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 50),
                              Text(year),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedYear = newValue ?? '';
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
                              const Icon(Icons.format_list_numbered),
                              const SizedBox(width: 50),
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
                              const Icon(Icons.book),
                              const SizedBox(width: 50),
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
                            elevation: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                          child: Text(
                                              'ชื่อ: ${attendance['name'] ?? 'ไม่มีข้อมูล'}')),
                                      Flexible(
                                          child: Text(
                                              'รหัสนิสิต: ${attendance['studentId'] ?? 'ไม่มีข้อมูล'}')),
                                    ],
                                  ),
                                  const SizedBox(height: 8.0),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'สถานะ: ',
                                              style: TextStyle(
                                                  color: Colors.black),
                                            ),
                                            TextSpan(
                                              text:
                                                  '${attendance['status'] ?? 'ไม่มีข้อมูล'}',
                                              style: TextStyle(
                                                color: attendance['status'] ==
                                                        'attended'
                                                    ? Colors.green
                                                    : attendance['status'] ==
                                                            'leave'
                                                        ? Colors.blue
                                                        : Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 8.0,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'ยอดเงินคงเหลือ: ',
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${attendance['balanceInEther'] ?? 'ไม่มีข้อมูล'}',
                                                style: const TextStyle(
                                                    color: Colors.green),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'ที่ได้รับ: ',
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${attendance['rewardAmount'] ?? 'ไม่มีข้อมูล'}',
                                                style: const TextStyle(
                                                    color: Colors.green),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 8.0,
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
