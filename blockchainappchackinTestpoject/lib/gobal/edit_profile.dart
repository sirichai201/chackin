import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../screen_login_user_all/login.dart';

class EditProfile extends StatefulWidget {
  final Map<String, dynamic> userData;
  EditProfile({required this.userData});
  @override
  _EditProfileState createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  late TextEditingController _nameController;
  late TextEditingController _passwordController;
  File? _selectedImage;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.userData['Username']);
    _passwordController =
        TextEditingController(); // สร้าง Controller สำหรับ password
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
      final ref = FirebaseStorage.instance
          .ref()
          .child('userImages')
          .child('${FirebaseAuth.instance.currentUser!.uid}.jpg');
      await ref.putFile(_selectedImage!);
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
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfilePicture(),
          const SizedBox(height: 20),
          _buildEditableTextField('Username:', _nameController),
          const SizedBox(height: 20),
          _buildNonEditableTextField('Email:', widget.userData['email']),
          const SizedBox(height: 20),
          _buildNonEditableTextField(
              'Student ID:', widget.userData['studentId']),
          const SizedBox(height: 20),
          _buildEditableTextField(
              'Password:', _passwordController), // เพิ่มฟิลด์ Password
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveProfileChanges,
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
                child: const Icon(Icons.edit, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTextField(
      String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8.0),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildNonEditableTextField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8.0),
        TextField(
          enabled: false, // ทำให้ไม่สามารถแก้ไขได้
          controller: TextEditingController(text: value),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  void _saveProfileChanges() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'Username': _nameController.text,
      });
      // ส่งค่า true กลับไปยังหน้าที่เปิดมา
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลถูกอัพเดทแล้ว!')),
      );
      Navigator.of(context).pop(true);
      // ถ้าผู้ใช้ต้องการเปลี่ยนรหัสผ่าน
      if (_passwordController.text.isNotEmpty) {
        final confirm = await _showConfirmationDialog(context);
        if (confirm) {
          await FirebaseAuth.instance.currentUser!
              .updatePassword(_passwordController.text);

          // Sign out ผู้ใช้
          await FirebaseAuth.instance.signOut();

          // ทำการ pop ทุกหน้าที่อยู่ใน stack และ push ไปหน้า login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => Login()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future _showConfirmationDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text(
              'การเปลี่ยนรหัสผ่านจะทําให้คุณต้องลงชื่อเข้าใช้อีกครั้ง คุณต้องการดําเนินการต่อหรือไม่?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }
}
