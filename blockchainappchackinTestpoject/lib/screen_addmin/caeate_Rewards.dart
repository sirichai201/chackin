import 'dart:io';
import 'package:blockchainappchackin/screen_addmin/user_admin.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateRewards extends StatefulWidget {
  @override
  _CreateRewardsState createState() => _CreateRewardsState();
}

class _CreateRewardsState extends State<CreateRewards> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final client = http.Client();
  String? name;
  double? balanceInEther; // ใช้ balanceInEther แทนตัวแปร coin
  int? quantity;
  File? _imageFile;
  BigInt toWei(double etherValue) {
    return BigInt.from(etherValue * 1e18);
  }

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> addRewardToServer() async {
    //final url = 'http://192.168.1.2:3000/addReward';
    final url = 'http://10.0.2.2:3000/addReward';
    final response = await client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'coinCost': toWei(balanceInEther!).toString(),
        'quantity': quantity.toString(),
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      print(responseBody);
      if (responseBody['status'] == 'success') {
        final blockHash = responseBody['data']['blockHash'];
        final lastRewardIndex = responseBody['data']['lastRewardIndex'];

        // ทำอะไรกับ blockHash และ lastRewardIndex ที่นี่ถ้าคุณต้องการ

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Success'),
              content: Text(responseBody['message'] +
                  '\nBlock Hash: $blockHash\nLast Reward Index: $lastRewardIndex'),
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
              content: Text('Failed to add reward in smart contract.'),
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

  // Future<int?> getLastRewardIndexFromServer() async {
  //   try {
  //     final url = 'http://192.168.1.2:3000/getLastRewardIndex';
  //     final response = await client.get(Uri.parse(url));

  //     if (response.statusCode == 200) {
  //       final responseBody = json.decode(response.body);
  //       if (responseBody['status'] == 'success') {
  //         return int.parse(responseBody['lastRewardIndex']);
  //       }
  //     }
  //     // ในกรณีที่ API ส่ง status กลับมาเป็น error
  //     print("Error from API: ${response.body}");
  //     return null;
  //   } catch (error) {
  //     print('Error getting lastRewardIndex: $error');
  //     // คุณสามารถแสดงข้อความผิดพลาดที่เกิดขึ้นหรือจัดการกับมันได้ที่นี่
  //     return null;
  //   }
  // }

  Future<void> addReward() async {
    if (_formKey.currentState?.validate() == true) {
      _formKey.currentState?.save();

      String? imageUrl;
      if (_imageFile != null) {
        final ref = _storage.ref('rewards/${DateTime.now().toIso8601String()}');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('rewards').add({
        'name': name,
        'imageUrl': imageUrl,
        'coin': balanceInEther,
        'quantity': quantity,
      });

      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => UserAdmin()));
    }
  }

  Future<void> addRewardAndSendToServer() async {
    if (_formKey.currentState?.validate() == true) {
      _formKey.currentState?.save();

      await addRewardToServer();
    }
    //await getLastRewardIndexFromServer();
    await addReward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('สร้างของรางวัล'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => UserAdmin()));
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_imageFile != null) Image.file(_imageFile!),
              ElevatedButton(
                onPressed: pickImage,
                child: Text('เลือกรูปภาพ'),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'ชื่อของรางวัล'),
                validator: (value) =>
                    value?.isEmpty == true ? 'กรุณาใส่ชื่อของรางวัล' : null,
                onSaved: (value) => name = value,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'จำนวนเหรียญที่ต้องการ'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                    value == null || double.tryParse(value) == null
                        ? 'กรุณาใส่จำนวนเหรียญในรูปแบบที่ถูกต้อง'
                        : null,
                onSaved: (value) =>
                    balanceInEther = double.tryParse(value ?? '0'),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'จำนวนของรางวัล'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || int.tryParse(value) == null
                        ? 'กรุณาใส่จำนวนของรางวัลในรูปแบบที่ถูกต้อง'
                        : null,
                onSaved: (value) => quantity = int.tryParse(value ?? '0'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: addRewardAndSendToServer,
                child: Text('ยืนยัน'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
