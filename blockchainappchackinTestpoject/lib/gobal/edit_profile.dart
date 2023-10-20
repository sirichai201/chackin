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
  bool _isLoadingImage = true; // New state variable to track image loading

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.userData['Username']);
    _passwordController = TextEditingController();
  }

  Future<void> _loadUserData() async {
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    if (mounted) {
      setState(() {
        _userData = userData.data() as Map<String, dynamic>;
        _isLoadingImage = false; // Set to false after loading user data
      });
    }
    print(_userData['imageURL']);
  }

  Future<void> _pickImage() async {
    setState(() {
      _isLoadingImage = true;
    });
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
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
      appBar: AppBar(title: const Text('แก้ไข้ โปรไฟล์')),
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
          _buildEditableTextField('ชื่อ:', _nameController),
          const SizedBox(height: 20),
          _buildNonEditableTextField('อีเมล์:', widget.userData['email']),
          const SizedBox(height: 20),
          _buildNonEditableTextField(
              'รหัสนิสิต:', widget.userData['studentId']),
          const SizedBox(height: 20),
          _buildEditableTextField('รหัสผ่าน:', _passwordController),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveProfileChanges,
            child: const Text('บันทึก'),
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
          _isLoadingImage
              ? const CircleAvatar(
                  radius: 100,
                  child: CircularProgressIndicator(),
                  backgroundColor: Color.fromARGB(255, 248, 245, 245),
                )
              : _userData.containsKey('imageURL') &&
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
          enabled: false,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลถูกอัพเดทแล้ว!')),
      );
      Navigator.of(context).pop(true);
      if (_passwordController.text.isNotEmpty) {
        final confirm = await _showConfirmationDialog(context);
        if (confirm) {
          await FirebaseAuth.instance.currentUser!
              .updatePassword(_passwordController.text);
          await FirebaseAuth.instance.signOut();
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
          title: const Text('ต้องการยืนยันหรือไม่'),
          content: const Text(
              'การเปลี่ยนรหัสผ่านจะทําให้คุณต้องลงชื่อเข้าใช้อีกครั้ง คุณต้องการดําเนินการต่อหรือไม่?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
  }
}
