import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RewardDetailPage extends StatefulWidget {
  final DocumentSnapshot reward;
  final double balanceInEther; // เพิ่ม balanceInEther เพื่อใช้ในการคำนวณ

  RewardDetailPage(
      {required this.reward,
      required this.balanceInEther}); // รับพารามิเตอร์ balanceInEther

  @override
  _RewardDetailPageState createState() => _RewardDetailPageState();
}

class EthereumBalance with ChangeNotifier {
  double? _balance = 0.0;

  double get balance => _balance ?? 0.0;

  set balance(double newBalance) {
    _balance = newBalance;
    notifyListeners();
  }

  void updateBalance(double newBalance) {
    _balance = newBalance;
    notifyListeners();
  }
}

class _RewardDetailPageState extends State<RewardDetailPage> {
  Future<bool> redeemRewardFromServer(String userAddress, double cost) async {
    final url = 'http://192.168.1.2:3000/redeemReward';
    final response = await http.post(
      Uri.parse(url),
      body: jsonEncode({
        'userAddress': userAddress,
        'cost': cost,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    return response.statusCode == 200;
  }

  void _redeemReward(double balance) async {
    final user = FirebaseAuth.instance.currentUser;
    final data = widget.reward.data() as Map<String, dynamic>;
    final coin = (data['coin'] as num?)?.toDouble() ?? 0.0;

    if (balance < coin) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เหรียญ Ethereum ไม่เพียงพอสำหรับการแลก')));
      return;
    }

    final success = await redeemRewardFromServer(user!.uid, coin);
    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('แลกของรางวัลสำเร็จ')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('แลกของรางวัลล้มเหลว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.reward.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Unknown';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final coin = (data['coin'] as num?)?.toDouble() ?? 0.0;
    final remainingQuantity = data['quantity'] as int? ?? 0;
    final currentBalance = widget.balanceInEther;

    return Scaffold(
      appBar: AppBar(
        title: Text('รายละเอียดของรางวัล'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'ยอดเหรียญ Ethereum ของคุณ: ${currentBalance?.toStringAsFixed(2) ?? '0.00'} ETH'),
            SizedBox(height: 10.0),
            if (imageUrl.isNotEmpty) Image.network(imageUrl),
            Text('Name: $name'),
            Text('Cost: ${coin.toStringAsFixed(2)} coins'),
            Text('Remaining Quantity: $remainingQuantity'),
            ElevatedButton(
              onPressed: () {
                if (currentBalance >= coin) {
                  _redeemReward(
                      currentBalance); // ส่งค่า currentBalance เข้าไปใน _redeemReward
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('เหรียญ Ethereum ไม่เพียงพอสำหรับการแลก')));
                }
              },
              child: Text('ยืนยันการแลกของรางวัล'),
            ),
          ],
        ),
      ),
    );
  }
}
