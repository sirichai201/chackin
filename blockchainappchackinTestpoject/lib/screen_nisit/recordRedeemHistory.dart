import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecordRedeemHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ประวัติการแลกของรางวัล'),
      ),
      body: _buildRedeemHistoryList(),
    );
  }

  Widget _buildRedeemHistoryList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Center(child: Text('กรุณาเข้าสู่ระบบเพื่อดูประวัติการแลก'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('redeem_history')
        .doc(user.uid)
        .collection('items')
        .orderBy('redeemed_at', descending: true)  // เรียงลำดับตามวันที่แลก
        .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('ยังไม่มีประวัติการแลก'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final imageUrl = doc['imageUrl'] as String? ?? '';

            return ListTile(
              leading: imageUrl.isNotEmpty 
                ? Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.error);  // แสดงไอคอน error เมื่อไม่สามารถโหลดรูปภาพได้
                    },
                  )
                : null,
              title: Text(doc['reward_name'] ?? 'Unknown'),
              subtitle: Text('Cost: ${doc['cost']} coins'),
              trailing: Text((doc['redeemed_at'] as Timestamp?)?.toDate().toString() ?? 'Unknown date'),
            );
          },
        );
      },
    );
  }
}
