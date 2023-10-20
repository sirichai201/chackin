// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class EditRewardPage extends StatefulWidget {
  final Map<String, dynamic> reward;

  EditRewardPage({required this.reward});

  @override
  _EditRewardPageState createState() => _EditRewardPageState();
}

class _EditRewardPageState extends State<EditRewardPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String apiUrl =
      "http://10.0.2.2:3000"; // เปลี่ยนเป็น IP และพอร์ตของเซิร์ฟเวอร์ของท่าน
  late TextEditingController _nameController;
  late TextEditingController _coinController;
  late TextEditingController _imageUrlController;
  late TextEditingController _quantityController;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  BigInt toWei(double etherValue) {
    return BigInt.from(etherValue * 1e18);
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.reward['name'] ?? '');
    _coinController =
        TextEditingController(text: widget.reward['coin']?.toString() ?? '');
    _imageUrlController =
        TextEditingController(text: widget.reward['imageUrl'] ?? '');
    _quantityController = TextEditingController(
        text: widget.reward['quantity']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coinController.dispose();
    _imageUrlController.dispose();
    _quantityController.dispose();

    super.dispose();
  }

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _sendUpdateRequest() async {
    final response = await http.post(
      Uri.parse("$apiUrl/updateReward"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        'rewardIndex': widget.reward['rewardIndex'],
        'newName': _nameController.text,
        'newCoinCost': toWei(double.parse(_coinController.text)).toString(),
        'newQuantity': int.parse(_quantityController.text),
      }),
    );

    // ย่อยแสดงผลเฉพาะตอนนี้สำหรับการ debug
    print(response.body);

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      if (responseBody['status'] == 'success') {
        // แจ้งเตือนเมื่อสำเร็จ
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Success'),
              content: Text(responseBody['message'] ?? 'Update successful.'),
              actions: <Widget>[
                ElevatedButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        // แจ้งเตือนเมื่อเกิดปัญหา
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content:
                  Text(responseBody['message'] ?? 'Failed to update reward.'),
              actions: <Widget>[
                ElevatedButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } else {
      // แจ้งเตือนเมื่อการเชื่อมต่อกับเซิร์ฟเวอร์มีปัญหา
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Failed to connect to server.'),
            actions: <Widget>[
              ElevatedButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  _updateReward() async {
    if (_formKey.currentState!.validate()) {
      // Check if ID is present
      if (widget.reward['id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: Document ID is missing!')));
        return;
      }

      try {
        await _firestore.collection('rewards').doc(widget.reward['id']).update({
          'name': _nameController.text,
          'coin': int.parse(_coinController.text),
          'imageUrl': _imageUrlController.text,
          'quantity': int.parse(_quantityController.text),
        });

        Navigator.of(context).pop();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating reward: $error')));
      }
    }
  }

  Future<void> sendUpdateRequestAndupdateReward_ToServer() async {
    await _sendUpdateRequest();
    await _updateReward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แก้ไข้ของรางวัล'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: sendUpdateRequestAndupdateReward_ToServer,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'ชื่อ'),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a name' : null,
            ),
            TextFormField(
              controller: _coinController,
              decoration: InputDecoration(labelText: 'ราคา'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter coin value' : null,
            ),
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(labelText: 'จำนวนสินค้า'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter quantity' : null,
            ),
            SizedBox(
              height: 20,
            ),
            if (_imageFile != null) Image.file(_imageFile!),
            ElevatedButton(
              onPressed: pickImage,
              child: Text('เลือกรูปภาพ'),
            ),
          ],
        ),
      ),
    );
  }
}
