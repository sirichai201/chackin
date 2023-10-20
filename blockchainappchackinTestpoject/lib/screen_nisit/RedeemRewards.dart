import 'package:blockchainappchackin/screen_nisit/User_nisit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'RewardDetailPage.dart';
import 'recordRedeemHistory.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class RedeemRewards extends StatefulWidget {
  final String uid;

  RedeemRewards({required this.uid});

  @override
  _RedeemRewardsState createState() => _RedeemRewardsState();
}

class _RedeemRewardsState extends State<RedeemRewards> {
  late String currentUserUid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUserUid = widget.uid;
    getCurrentUser().then((_) => _printUserEthereumAddress());
  }

  Future<void> getCurrentUser() async {
    currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _printUserEthereumAddress() async {
    await getCurrentUser();
    if (currentUser?.uid != null) {
      String? ethAddress = await fetchUserEthereumAddress(currentUser!.uid);
      if (ethAddress != null) {
        setState(() {
          currentUserUid = ethAddress;
        });
        _fetchUserEthereumBalance(); // เรียกใช้ฟังก์ชั่นเพื่ออัปเดตยอดเงิน Ethereum
      }
    }
  }

  Future<String?> fetchUserEthereumAddress(String uid) async {
    final userDocument = await _firestore.collection('users').doc(uid).get();
    return userDocument.data()?['ethereumAddress'];
  }

  Future<void> _fetchUserEthereumBalance() async {
    if (currentUserUid != null) {
      double? balance = await fetchUserEthereumBalance(currentUserUid);
      if (balance != null) {
        Provider.of<EthereumBalance>(context, listen: false)
            .updateBalance(balance);
      }
    }
  }

  Future<double?> fetchUserEthereumBalance(String uid) async {
    // ใช้ uid ตรงนี้แทน currentUserUid
    final url = 'http://10.0.2.2:3000/getBalance/$uid';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData.containsKey('balanceInEther')) {
        try {
          double? balanceInEther =
              double.parse(responseData['balanceInEther'].toString());
          return balanceInEther;
        } catch (e) {
          return null;
        }
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceFromProvider = Provider.of<EthereumBalance>(context).balance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการของรางวัล'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => UserNisit()));
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => RecordRedeemHistory()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 2.0),
                borderRadius: BorderRadius.circular(15.0),
                color: const Color.fromARGB(255, 29, 124, 37),
              ),
              child: Text(
                'ยอดเหรียญของคุณ: ${balanceFromProvider?.toStringAsFixed(2) ?? '0.00'} เหรียญ',
                style: const TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('rewards').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('ไม่มีรางวัลที่สามารถแลกได้ในขณะนี้'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final DocumentSnapshot reward = snapshot.data!.docs[index];
                    final Map<String, dynamic> rewardData =
                        reward.data() as Map<String, dynamic>;
                    final String imageUrl =
                        rewardData['imageUrl'] as String? ?? '';
                    final String name =
                        rewardData['name'] as String? ?? 'Unknown';
                    final double coin =
                        (rewardData['coin'] as num?)?.toDouble() ?? 0.0;
                    final int quantity = rewardData['quantity'] as int? ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 15.0, vertical: 8.0),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RewardDetailPage(
                                reward: reward,
                                balanceInEther: balanceFromProvider ??
                                    0.0, // ส่ง balanceInEther มาที่นี่
                              ),
                            ),
                          );
                        },
                        leading: imageUrl.isNotEmpty
                            ? Container(
                                width: 50.0,
                                height: 50.0,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : const Icon(Icons.image_not_supported),
                        title: Text(name),
                        subtitle: Text(
                            'Cost: ${coin.toStringAsFixed(2)} coins - Available: $quantity'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
