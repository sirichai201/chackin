// นี่คือตัวอย่างโค้ดสำหรับหน้า Profile
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'drawerbar_lecturer.dart';

import 'edit_profile_lecturer.dart';

class profile_lecturer extends StatefulWidget {
  @override
  _profile_lecturerState createState() => _profile_lecturerState();
}

class _profile_lecturerState extends State<profile_lecturer> {
  final user = FirebaseAuth.instance.currentUser;
  File? _profileImage;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    if (mounted) {
      setState(() {
        _userData = userData.data() as Map<String, dynamic>;
      });
    }
    print(
        _userData['imageURL']); // ทดสอบว่า URL ของรูปภาพมีการเปลี่ยนแปลงหรือไม่
  }

  // ignore: unused_element
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _profileImage = File(pickedFile.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('userImages')
          .child('${FirebaseAuth.instance.currentUser!.uid}.jpg');
      await ref.putFile(_profileImage!);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'imageURL': url});
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: const DrawerbarLecturer(),
      body: _buildProfileBody(),
    );
  }

  Widget _buildProfileBody() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 25),
          _userData.containsKey('imageURL') &&
                  _userData['imageURL'] != null &&
                  _userData['imageURL'].isNotEmpty
              ? CircleAvatar(
                  radius: 100,
                  backgroundImage: NetworkImage(_userData['imageURL']),
                )
              : const CircleAvatar(
                  radius: 100,
                  backgroundImage: AssetImage('assets/images/Profile.png'),
                ),
          const SizedBox(height: 25),
          const Align(
            alignment: Alignment.center,
            child: FractionalTranslation(
              translation: Offset(0.0, 0.0),
              child: Text(
                'ข้อมูลบัญชี',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildProfileDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 2),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 15),
          Text(
            'ชื่อนามสกุล: ${_userData['Username']}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 10),
          Text(
            'Email: ${_userData['email']}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _navigateToEditProfile,
            child: const Text('แก้ไขข้อมูล'),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Future<void> _navigateToEditProfile() async {
    var result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileLecturer(userData: _userData),
      ),
    );
    if (result != null) {
      _loadUserData(); // เมื่อหน้า EditProfile ถูกปิด จะทำการโหลดข้อมูลใหม่
    }
  }
}
