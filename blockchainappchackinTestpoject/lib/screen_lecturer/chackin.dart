import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class CheckInPage extends StatefulWidget {
  final String userId;
  final String docId;

  CheckInPage({required this.userId, required this.docId});

  @override
  _CheckInPageState createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String scheduleId =
      DateTime.now().toIso8601String().split('T')[0]; // กำหนดค่าเริ่มต้น

  late TextEditingController _dateController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  LocationData? _locationData;
  bool _isChecking = false;
  Timer? _timer; // สร้างตัวแปร Timer
  late DateTime endDateTime;
  double universityLat = 17.272961;
  double universityLong = 104.131919;
  double allowedDistance = 100.0; // in meters

  bool isSettingsReady() {
    print("isSettingsReady: ${_locationData != null}"); // ใส่ print ที่นี่
    // คุณสามารถเพิ่มเงื่อนไขการตรวจสอบข้อมูลอื่น ๆ ได้ที่นี่
    return _locationData != null;
  }

  bool isWithinTimeRange() {
    final currentTime = DateTime.now();
    final startTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _startTime.hour, _startTime.minute);
    final endTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _endTime.hour, _endTime.minute);
    print(
        'Is within time range: ${currentTime.isAfter(startTime) && currentTime.isBefore(endTime)}'); // ใส่ print ที่นี่
    print('Current Time: $currentTime');
    print('Start Time: $startTime');
    print('End Time: $endTime');

    return currentTime.isAfter(startTime) && currentTime.isBefore(endTime);
  }

  bool isWithinUniversity(LocationData? locationData) {
    if (locationData == null) return false;

    const earthRadius = 6371.0; // in km

    double toRadian(double degree) => degree * (3.14159265359 / 180.0);

    double deltaLat = toRadian(locationData.latitude! - universityLat);
    double deltaLong = toRadian(locationData.longitude! - universityLong);

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(toRadian(universityLat)) *
            cos(toRadian(locationData.latitude!)) *
            sin(deltaLong / 2) *
            sin(deltaLong / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    double distance = earthRadius * c; // in km

    return distance <= (allowedDistance / 1000.0); // allowedDistance in m
  }

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();

    _startTime = TimeOfDay.now();
    _endTime = TimeOfDay.now();
    _selectedDate = DateTime.now(); //_selectedDate = DateTime(2023, 9, 26);
    scheduleId = _selectedDate.toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _manageCheckInClosing(DateTime endDateTime) async {
    final duration = endDateTime.difference(DateTime.now());
    _timer = Timer(duration, () {
      if (mounted) {
        print("Check-in is now closed!"); // ใส่ print ที่นี่
        setState(() {
          _isChecking = false;
        });
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != _selectedDate)
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text =
            _selectedDate.toLocal().toIso8601String().split('T')[0];
        scheduleId = _selectedDate.toIso8601String().split('T')[0];
      });
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (pickedTime != null) {
      final now = DateTime.now();
      final selectedTime = DateTime(
          now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);

      if (selectedTime.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกเวลาที่ยังไม่ผ่านไป')),
        );
        return;
      }

      setState(() {
        _startTime = pickedTime;
        _startTimeController.text = pickedTime.format(context);
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (pickedTime != null) {
      final now = DateTime.now();
      final selectedTime = DateTime(
          now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);

      if (selectedTime.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกเวลาที่ยังไม่ผ่านไป')),
        );
        return;
      }

      setState(() {
        _endTime = pickedTime;
        _endTimeController.text = pickedTime.format(context);
      });
    }
  }

  Future<void> _getLocation() async {
    final location = Location();
    final LocationData locationData = await location.getLocation();

    setState(() {
      _locationData = locationData;
    });
    print(
        'LocationData: ${_locationData?.latitude}, ${_locationData?.longitude}');
  }

  Future<void> _saveAttendanceSchedule() async {
    print(
        "Saving Attendance Schedule..."); // Debugging: Add a print statement here
    print("ScheduleId: $scheduleId");

    print(
        "LocationData: ${_locationData?.latitude}, ${_locationData?.longitude}");

    final subjects = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('subjects');
    final subjectDoc = subjects.doc(widget.docId);

    final attendanceSchedules = subjectDoc.collection('attendanceSchedules');

    // สร้าง scheduleId ที่ unique ตามวันที่
    scheduleId = _selectedDate.toIso8601String().split('T')[0];
    final attendanceScheduleDoc = attendanceSchedules.doc(scheduleId);

    final DateTime startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final DateTime endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    await _manageCheckInClosing(endDateTime);
    final Map<String, dynamic> data = {
      'startDate': startDateTime,
      'endDate': endDateTime,
      'location': {
        'lat': _locationData?.latitude ?? 17.272961,
        'long': _locationData?.longitude ?? 104.131919,
      },
      'studentsChecked': [],
    };

    await attendanceScheduleDoc.set(data).then((_) async {
      print("Schedule saved successfully!");
    }).catchError((error) => print("Failed to save schedule: $error"));
    // Debugging: Handle error here

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Schedule saved!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-In Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              readOnly: true,
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Date',
                suffixIcon: IconButton(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                ),
              ),
            ),
            TextField(
              readOnly: true,
              controller: _startTimeController,
              decoration: InputDecoration(
                labelText: 'Start Time',
                suffixIcon: IconButton(
                  onPressed: _selectStartTime,
                  icon: const Icon(Icons.access_time),
                ),
              ),
            ),
            TextField(
              readOnly: true,
              controller: _endTimeController,
              decoration: InputDecoration(
                labelText: 'End Time',
                suffixIcon: IconButton(
                  onPressed: _selectEndTime,
                  icon: const Icon(Icons.access_time),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _getLocation();
                if (isWithinUniversity(_locationData)) {
                  // User is within the university, allow check-in
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('You are within the University!')),
                  );
                } else {
                  // User is not within the university, disallow check-in
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('You are not within the University!')),
                  );
                }
                print(
                    'Location: ${_locationData?.latitude}, ${_locationData?.longitude}');
                print(
                    'Is within university: ${isWithinUniversity(_locationData)}');
              },
              child: const Text('Get Location '),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                print("Button Pressed");
                print("Is Settings Ready: ${isSettingsReady()}");
                print("Is Within Time Range: ${isWithinTimeRange()}");
                setState(() {
                  _isChecking = !_isChecking;
                  if (_isChecking) {
                    _manageCheckInClosing(DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      _endTime.hour,
                      _endTime.minute,
                    ));
                    if (isSettingsReady()) {
                      // เรียก method _saveAttendanceSchedule เมื่อ _isChecking ถูกตั้งค่าเป็น true และอยู่ในช่วงเวลาที่กำหนด
                      _saveAttendanceSchedule();
                    }
                  } else {
                    print(
                        "Cannot check-in: Settings not ready or not within time range.555");
                  }
                });
              },
              icon: Icon(Icons.check_circle),
              label: Text(_isChecking ? 'เปิดเช็คอิน' : 'ปิดเช็คอิน'),
              style: ElevatedButton.styleFrom(
                primary: _isChecking ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('subjects')
                  .doc(widget.docId)
                  .collection('attendanceSchedules')
                  .doc(scheduleId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const CircularProgressIndicator();

                if (!snapshot.hasData || snapshot.data!.data() == null) {
                  print('No attendance data available for $scheduleId.');
                  return const Text('ยังไม่มีข้อมูลการเช็คชื่อ');
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;

                final studentsChecked =
                    (data['studentsChecked'] as List<dynamic>? ?? []);

                if (studentsChecked.isEmpty)
                  return const Text('ยังไม่มีนิสิตที่เช็คชื่อ');

                final attendedCount = studentsChecked
                    .where((student) => student['status'] == 'attended')
                    .length;
                final absentCount = studentsChecked
                    .where((student) => student['status'] == 'absent')
                    .length;
                final leaveCount = studentsChecked
                    .where((student) => student['status'] == 'leave')
                    .length;

                return Column(
                  children: [
                    _buildInfoBox('มาเรียน', Colors.green, attendedCount),
                    _buildInfoBox('ขาดเรียน', Colors.red, absentCount),
                    _buildInfoBox('ลา', Colors.orange, leaveCount),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, Color color, int count) {
    return Card(
      child: ListTile(
        title: Text('$title: $count คน', style: TextStyle(color: color)),
      ),
    );
  }

  void _toggleAttendance() {
    setState(() {
      _isChecking = !_isChecking;
    });
  }
}
