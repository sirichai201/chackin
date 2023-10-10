// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// final user = FirebaseAuth.instance.currentUser;
// final useruid = user?.uid;

// String scheduleId =
//     DateTime.now().toIso8601String().split('T')[0]; // กำหนดค่าเริ่มต้น

// class AttendanceChecker {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   Future<String?> getSubjectsId() async {
//     QuerySnapshot subjectSnapshot = await _firestore
//         .collection('users')
//         .doc(useruid)
//         .collection('subjects')
//         .get();

//     if (subjectSnapshot.docs.isNotEmpty) {
//       return subjectSnapshot
//           .docs.first.id; // ใช้เอกสารแรก (หรือเลือกตามความต้องการ)
//     }
//     return null;
//   }

//   Future<DateTime?> getEndTime() async {
//     String? subjectsId = await getSubjectsId();

//     if (subjectsId != null) {
//       DocumentSnapshot snapshot = await _firestore
//           .collection('users')
//           .doc(useruid)
//           .collection('subjects')
//           .doc(subjectsId)
//           .collection('attendanceSchedules')
//           .doc(scheduleId)
//           .get();

//       if (snapshot.exists && snapshot.data() != null) {
//         await _markAbsentStudents();
//         return snapshot['endTime'].toDate();
//       }
//       return null;
//     }
//     return null;
//   }

//   Future<void> _markAbsentStudents() async {
//     final subjects = FirebaseFirestore.instance
//         .collection('users')
//         .doc(useruid)
//         .collection('subjects');
//     final subjectDoc = subjects.doc(subjectsId);

//     // ดึงรายชื่อนิสิตทั้งหมด
//     final studentsList = await subjectDoc.get().then((doc) {
//       if (doc.exists) {
//         return List<Map<String, dynamic>>.from(doc['students']);
//       }
//       return [];
//     });

//     final studentIds =
//         studentsList.map((student) => student['studentId']).toList();

//     return FirebaseFirestore.instance.runTransaction((transaction) async {
//       final scheduleSnapshot = await transaction
//           .get(subjectDoc.collection('attendanceSchedules').doc(scheduleId));

//       if (!scheduleSnapshot.exists) {
//         // Handle error: the document doesn't exist.
//         return;
//       }

//       final currentCheckedStudents = List<Map<String, dynamic>>.from(
//           scheduleSnapshot.data()?['studentsChecked'] ?? []);

//       final absentStudents = studentIds
//           .where((id) => !currentCheckedStudents
//               .any((student) => student['studentId'] == id))
//           .toList();

//       for (var absentStudentId in absentStudents) {
//         var studentData = studentsList.firstWhere(
//             (s) => s['studentId'] == absentStudentId,
//             orElse: () => <String, dynamic>{});

//         if (!studentData.containsKey('studentId')) continue;

//         var studentName = studentData['name'];
//         var studentUid = studentData['uid'];

//         // ตรวจสอบว่านิสิตนั้นถูกเพิ่มเข้าไปใน studentsChecked หรือยัง
//         bool isStudentAlreadyChecked = currentCheckedStudents
//             .any((student) => student['studentId'] == absentStudentId);

//         // ถ้ายังไม่ถูกเพิ่มเข้าไป จึงทำการเพิ่ม
//         if (!isStudentAlreadyChecked) {
//           final absentStudentData = {
//             'studentId': absentStudentId,
//             'name': studentName,
//             'status': 'absent',
//             'time': Timestamp.now(),
//             'uid': studentUid,
//           };

//           currentCheckedStudents.add(absentStudentData);
//           // อัปเดตข้อมูลเข้าฝั่งนิสิต
//           await _updateStudentRecord(absentStudentData, studentUid);
//         }
//       }

//       // ทำการอัพเดทข้อมูลลงในฐานข้อมูลโดยใช้ transaction
//       transaction.update(
//           subjectDoc.collection('attendanceSchedules').doc(scheduleId),
//           {'studentsChecked': currentCheckedStudents});
//     });
//   }

//   Future<void> _updateStudentRecord(
//       Map<String, dynamic> checkInData, String studentUid) async {
//     final studentSubjectRef = _firestore
//         .collection('users')
//         .doc(studentUid) // ใช้ uid ของนิสิตเป็น document ID
//         .collection('enrolledSubjects')
//         .doc(docId);

//     final studentAttendanceScheduleRef = studentSubjectRef
//         .collection('attendanceSchedulesRecords')
//         .doc(DateTime.now().toLocal().toString().split(' ')[0]);

//     // ทำการเช็คว่ามี document นี้หรือยัง ถ้ายังก็สร้าง
//     if (!(await studentAttendanceScheduleRef.get()).exists) {
//       await studentAttendanceScheduleRef.set({
//         // เพิ่มข้อมูลเบื้องต้นที่คุณต้องการจะเก็บไว้
//       });
//     }

//     // อ่านข้อมูลที่มีอยู่
//     DocumentSnapshot snapshot = await studentAttendanceScheduleRef.get();
//     List existingData;
//     if (snapshot.exists && snapshot.data() != null) {
//       existingData =
//           (snapshot.data() as Map<String, dynamic>)['studentsCheckedRecords'] ??
//               [];
//     } else {
//       existingData = [];
//     }

//     // ตรวจสอบว่าข้อมูลนั้นยังไม่มีอยู่
//     bool alreadyExists = existingData
//         .any((data) => data['studentId'] == checkInData['studentId']);

//     // ถ้าไม่มี, ค่อยทำการบันทึกข้อมูล
//     if (!alreadyExists) {
//       await studentAttendanceScheduleRef.update({
//         'studentsCheckedRecords': FieldValue.arrayUnion([checkInData])
//       });
//     }
//   }
// }
