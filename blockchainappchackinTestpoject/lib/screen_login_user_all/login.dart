// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../screen_addmin/user_admin.dart';
import '../screen_lecturer/User_lecturer.dart';
import '../screen_nisit/User_nisit.dart';
import 'forget_password.dart';

class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isValidEmail(String email) {
    final RegExp regex = RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return regex.hasMatch(email);
  }

  Future<void> _login() async {
    if (!isValidEmail(_usernameController.text.trim())) {
      _showErrorDialog(context, 'Please enter a valid email format.');
      return;
    }
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: _usernameController.text,
              password: _passwordController.text);

      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final userRole = doc.data()?['role'] ?? '';

        switch (userRole) {
          case 'นิสิต':
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => UserNisit()));
            break;
          case 'อาจารย์':
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => UserLecturer()));
            break;
          case 'admin':
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => UserAdmin()));
            break;
          default:
            _showErrorDialog(context, 'User role not recognized.');
            break;
        }
      }
    } on FirebaseAuthException catch (e) {
      print("Error code: ${e.code}");
      switch (e.code) {
        case 'user-not-found':
          _showErrorDialog(context, 'No account associated with this email.');
          break;
        case 'wrong-password':
          _showErrorDialog(context, 'Incorrect password. Please try again.');
          break;
        default:
          _showErrorDialog(
              context, 'รหัสผ่านหรือ อีเมลไม่ถูกต้องกรุณาลองใหม่.');
          break;
      }
    } // ... [rest of your error handling]
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ผิดพลาด'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('ตกลง'),
              onPressed: () {
                Navigator.of(context).pop(); // Closes the dialog
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15), // Rounded edges for the dialog
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('เข้าสู่ระบบ')),
      ),
      body: Padding(
        padding: EdgeInsets.all(30.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 30.0),
              _buildUsernameField(),
              const SizedBox(height: 20.0),
              _buildPasswordField(),
              const SizedBox(height: 20.0),
              _loginButton(context),
              const SizedBox(height: 10.0),
              _buildForgetPasswordButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/ku.png',
      width: 100,
      height: 150,
    );
  }

  Widget _buildUsernameField() {
    return TextField(
      controller: _usernameController,
      decoration: const InputDecoration(labelText: 'อีเมล์'),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
    );
  }

  Widget _loginButton(BuildContext context) {
    return ElevatedButton(
      onPressed: _login,
      child: Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 18)),
    );
  }

  Widget _buildForgetPasswordButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForgetPassword(),
          ),
        );
      },
      child: const Text('ลืมรหัสผ่าน?'),
    );
  }
}
