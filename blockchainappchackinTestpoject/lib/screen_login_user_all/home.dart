import 'package:flutter/material.dart';

import 'login.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text('แอพเช็คชื่อ'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  "assets/images/ku.png",
                  width: 209,
                  height: 300,
                ),
                const SizedBox(
                  height: 20,
                ),
                Container(
                  width: 200,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(8.0), // เพิ่มความมนเขียนมุม
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 3,
                        blurRadius: 5,
                        offset: const Offset(0, 3), // เพิ่มเงา
                      ),
                    ],
                    border: Border.all(
                      color: Colors.red,
                      width: 4.0,
                      style: BorderStyle.solid,
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0), // เพิ่มระยะห่าง
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "แอพพริเคชั่นเช็คชื่อเข้าเรียน",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10), // ระยะห่างระหว่างข้อความ
                      Text(
                        "จัดทำมาเพื่อให้ใช้งานกับอาจารย์และนิสิตเพื่อ สะดวกและรวดเร็วในการเช็คชื่อ",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "และสามารถดูประวัติย้อนหลังได้พร้อมทั้งสามารถได้รับเหรีญญethเพื่อสะสมแลกของรางวัล",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (context) {
              return Login();
            },
          ));
        },
        child: const Icon(Icons.arrow_forward),
        backgroundColor: Colors.red,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
