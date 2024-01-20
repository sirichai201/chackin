// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screen_login_user_all/login.dart';

/// หน้าสร้างบัญชีผู้ใช้
class CreateUser extends StatefulWidget {
  @override
  _CreateUserState createState() => _CreateUserState();
}

class _CreateUserState extends State<CreateUser> {
  // ตัวควบคุมข้อมูลที่ผู้ใช้ป้อนลงใน TextField
  TextEditingController _studentIdController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  String? _selectedRole;

  /// สร้างบัญชีผู้ใช้ใน Firebase
  Future<void> _createUser() async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (userCredential.user?.uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user?.uid)
            .set({
          'studentId': _studentIdController.text,
          'email': _emailController.text,
          'role': _selectedRole,
          'Username': _usernameController.text,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'บัญชีผู้ใช้ถูกสร้างเรียบร้อยแล้ว ด้วย Role: $_selectedRole')),
        );
      } else {
        throw Exception(
            'ไม่สามารถรับ UID ของผู้ใช้จาก Firebase Authentication ได้');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('มีข้อผิดพลาด: $e')),
      );
    }
  }

  /// สร้าง Dropdown เพื่อเลือก role
  DropdownButton<String> buildDropdown() {
    return DropdownButton<String>(
      value: _selectedRole,
      onChanged: (String? newValue) {
        setState(() {
          _selectedRole = newValue;
        });
      },
      items: <String>['นิสิต', 'อาจารย์']
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      hint: Text('กำหนดผู้ใช้'),
    );
  }

  /// สร้าง TextField สำหรับป้อน Username
  /// สร้าง TextField สำหรับป้อน Username
  TextField buildUsernameField() {
    return TextField(
      controller: _usernameController,
      decoration: const InputDecoration(
        labelText: 'ชื่อ',
      ),
    );
  }

  /// สร้าง TextField สำหรับป้อน Password
  TextField buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'รหัสผ่าน',
      ),
    );
  }

  /// สร้าง TextField สำหรับป้อน รหัสนิสิต
  TextField buildStudentIdField() {
    return TextField(
      controller: _studentIdController,
      decoration: const InputDecoration(
        labelText: 'รหัสนิสิต',
      ),
    );
  }

  /// สร้าง TextField สำหรับป้อน email
  TextField buildEmailField() {
    return TextField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'อีเมล',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('สร้างบัญชี'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => Login()));
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            buildStudentIdField(),
            const SizedBox(height: 16),
            buildEmailField(),
            const SizedBox(height: 16),
            buildUsernameField(), // สามารถเอาไว้เป็น email backup หรือไม่ใช้ก็ได้
            const SizedBox(height: 16),
            buildPasswordField(),
            const SizedBox(height: 16),
            buildDropdown(),
            const SizedBox(height: 16),
            buildCreateButton(context),
          ],
        ),
      ),
    );
  }

  ElevatedButton buildCreateButton(BuildContext context) {
    return ElevatedButton(
      onPressed: _createUser,
      child: Text('สร้างบัญชี'),
    );
  }
}
