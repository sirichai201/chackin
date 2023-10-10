
require('dotenv').config();


const admin = require('firebase-admin');
const Web3 = require('web3');
const express = require('express');
const cors = require('cors');


const app = express();
const bodyParser = require('body-parser');

app.use(bodyParser.json()); 

app.use(express.json());
const web3 = new Web3('http://127.0.0.1:7545');

app.use(cors()); 

const path = require('path');
const fs = require('fs');

const contractJSONPath = path.join(__dirname, '..', 'smartcontrace', 'build', 'contracts', 'MyContract.json');
const contractJSON = JSON.parse(fs.readFileSync(contractJSONPath, 'utf8'));
const abi = contractJSON.abi;


const privateKey = process.env.PRIVATE_KEY; 
const senderAddress = process.env.SENDER_ADDRESS;
const contractAddress =  process.env.CONTRACT_ADDRESS;
const contract = new web3.eth.Contract(abi, contractAddress);

const serviceAccount = require('./projectblockchainapp-9defb-firebase-adminsdk-2doub-bab55a8ad3.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();



app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// สร้าง endpoint '/sendEther' ด้วย HTTP POST method สำหรับการส่ง Ether
app.post('/sendEther', async (req, res) => {
  try {
    const { receiverAddress } = req.body;

    // ตรวจสอบว่า receiverAddress ที่ได้รับมาเป็น Ethereum address ที่ถูกต้องหรือไม่
    if (!web3.utils.isAddress(receiverAddress)) {
      return res.status(400).send('ที่อยู่ Ethereum ไม่ถูกต้อง');
    }
    console.log(`เริ่มต้นการส่ง Ether ไปยัง ${receiverAddress}...`);

  
    const amountInEther = '0.05';
    const amountInWei = web3.utils.toWei(amountInEther, 'ether');

    const rawTransaction = {
      from: senderAddress,
      to: receiverAddress, // ใช้ receiverAddress ที่ได้รับมา
      gas: await contract.methods.rewardStudent(receiverAddress).estimateGas({from: senderAddress}),
      data: contract.methods.rewardStudent(receiverAddress).encodeABI(),
      value: amountInWei
    };

    const signedTransaction = await web3.eth.accounts.signTransaction(rawTransaction, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTransaction.rawTransaction);
    console.log('Transaction Receipt:', receipt);

    res.json({ rewardAmount: amountInEther });
    console.log(`ส่ง Ether ไปยัง ${receiverAddress} สำเร็จ.`);
  } catch (error) {
    console.error('ผิดพลาด:', error);
    res.status(500).send(error.toString());
  }
});




app.post('/createEthereumAddress', async (req, res) => {
  let userId; 

  try {
      if (!req.body || !req.body.userId) {
          return res.status(400).send('ต้องการ userId');
      }

      userId = req.body.userId;

      const account = web3.eth.accounts.create();

      const userDocRef = db.collection('users').doc(userId);
      await userDocRef.set({
        ethereumAddress: account.address,
      }, { merge: true });
  
      res.json({
        ethereumAddress: account.address,
        ethereumPrivateKey: account.privateKey
      });
    } catch (error) {
        console.error('ผิดพลาด:', error);
        console.error('รับ userId:', userId); 
        res.status(500).send(error.toString());
    }
});

app.get('/getBalance/:address', async (req, res) => {
  try {
      const address = req.params.address;
      if (!web3.utils.isAddress(address)) {
          return res.status(400).send('ที่อยู่ Ethereum ไม่ถูกต้อง');
      }

      const balanceInWei = await web3.eth.getBalance(address);
      const balanceInEther = web3.utils.fromWei(balanceInWei, 'ether');

      res.json({
          address: address,
          balanceAmount: balanceInWei,
          balanceInEther: balanceInEther
      });
  } catch (error) {
      console.error('ผิดพลาด:', error);
      res.status(500).send(error.toString());
  }
});




app.post('/addReward', async (req, res) => {
  console.log('Received data from Flutter:', req.body);
  const { name, coinCost, quantity } = req.body;
  try {
     // ประเมินค่า gas
      const estimatedGas = await contract.methods.addReward(name, coinCost, quantity).estimateGas({ from: senderAddress });

      // ส่งธุรกรรมด้วยค่า gas ที่ประเมิน
      const txReceipt = await contract.methods.addReward(name, coinCost, quantity).send({ from: senderAddress, gas: estimatedGas });
      if (txReceipt.status === true) {
          const rewardAddedEvent = txReceipt.events.RewardAdded;
          if (rewardAddedEvent) {
              const eventData = rewardAddedEvent.returnValues;
              const rewardName = eventData.name;
              const rewardCoinCost = eventData.coinCost;
              const rewardQuantity = eventData.quantity;
              const rewardOwner = eventData.rewardAddress;
              console.log("Event Data:", eventData);

              const allRewardsData = await contract.methods.getCompleteRewardData().call();
              const rewardsList = allRewardsData[0]; // คืนค่ารายการของรางวัลทั้งหมด
              const lastRewardIndex = allRewardsData[1]; // คืนค่า index ของรายการรางวัลล่าสุด

              res.json({
                  status: 'success',
                  message: 'Reward added successfully.',
                  data: {
                      name: rewardName,
                      coinCost: rewardCoinCost,
                      quantity: rewardQuantity,
                      blockHash: txReceipt.blockHash,
                      lastRewardIndex: lastRewardIndex,
                      allRewards: rewardsList // เพิ่มข้อมูลรายการของรางวัลทั้งหมด
                  }
              });
          } else {
              throw new Error('RewardAdded event not emitted');
          }
      } else {
          throw new Error('Transaction failed');
      }
  } catch (error) {
      console.error('Failed to add reward in smart contract.', error);
      res.status(500).send('Internal Server Error.');
  }
});



//ดึงเอาlastRewardIndex ที่สร้างล่าสุด
app.get('/getLastRewardIndex', async (req, res) => {
  try {
      const contractInstance = new web3.eth.Contract(abi, contractAddress);
      const lastRewardIndex = await contractInstance.methods.getLastRewardIndex().call();
      if (typeof lastRewardIndex !== 'undefined' && lastRewardIndex !== null) {
          res.json({
              status: 'success',
              lastRewardIndex: lastRewardIndex
          });
      } else {
          res.json({
              status: 'error',
              message: 'Failed to retrieve the last reward index.'
          });
      }
  } catch (error) {
      console.error('Error getting lastRewardIndex:', error);
      res.status(500).send('Internal Server Error.');
  }
});







//แก้ไข้ข้อมูลรายการของรางวัล
app.post('/updateReward', async (req, res) => {
  try {
    console.log('Coin cost received from Flutter:', coinCost);
      console.log('Received data for updating reward:', req.body);
      const { rewardIndex, newName, newCoinCost, newQuantity } = req.body;

      const tx = await contract.methods.updateReward(rewardIndex, newName, newCoinCost, newQuantity).send({ from: senderAddress });
      console.log('Coin cost received from Flutter:', coinCost);

      if (tx.status === true) {
          res.json({
              status: 'success',
              message: 'Reward updated successfully.',
              data: {
                  name: newName,
                  coinCost: newCoinCost,
                  quantity: newQuantity
              }
          });
      } else {
          throw new Error('Failed to update reward in smart contract.');
      }
  } catch (error) {
      console.error('Error:', error);
      res.status(500).send('Internal Server Error.');
  }
});

//ลบรายการของรายวัล
app.post('/deleteReward', async (req, res) => {
  try {
      console.log('Received request to delete reward:', req.body);
      const { rewardIndex } = req.body;

      const tx = await contract.methods.deleteReward(rewardIndex).send({ from: senderAddress });
      
      if (tx.status === true) {
          res.json({
              status: 'success',
              message: 'Reward deleted successfully.'
          });
      } else {
          throw new Error('Failed to delete reward in smart contract.');
      }
  } catch (error) {
      console.error('Error:', error);
      res.status(500).send('Internal Server Error.');
  }
});



// แลกของรางวัล
app.post('/exchangeReward', async (req, res) => {
  try {
      const { userAddress, rewardIndex } = req.body;
      const tx = await contract.methods.redeemReward(rewardIndex).send({ from: userAddress });
      if (tx.status === true) {
          res.status(200).send('Reward exchanged successfully.');
      } else {
          throw new Error('Failed to exchange reward in smart contract.');
      }
  } catch (error) {
      console.error('Error:', error);
      res.status(500).send('Internal Server Error.');
  }
});

// ดูประวัติการแลก
app.get('/getRedemptionHistory/:userAddress', async (req, res) => {
  try {
      const userAddress = req.params.userAddress;
      const history = await contract.methods.getRedemptionHistory(userAddress).call();
      res.json(history);
  } catch (error) {
      console.error('Error:', error);
      res.status(500).send('Internal Server Error.');
  }

});

app.get('/test', async (req, res) => {
  return res.status(200).send("OK")
});





const PORT = 3000;
app.listen(PORT, () => console.log(`เซิร์ฟเวอร์กำลังทำงานที่พอร์ต ${PORT}`));
