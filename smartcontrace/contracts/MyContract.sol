// กำหนด license สำหรับ Smart Contract
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4; // กำหนดเวอร์ชันของ Solidity

// สร้าง Smart Contract ชื่อ MyContract
contract MyContract {

    // ตัวแปรสถานะ
    mapping(address => uint256) public balances; // ยอดเงินของแต่ละที่อยู่
    address public owner; // เจ้าของ Smart Contract
    Reward[] public rewards; // รายการของรางวัล
    mapping(address => Redemption[]) public redemptionHistory; // ประวัติการแลกรางวัลของแต่ละที่อยู่

    // เหตุการณ์ที่เกิดขึ้น
    event SpentCoin(address indexed student, uint256 amount); // เหตุการณ์เมื่อนิสิตใช้เหรียญ
    event Rewarded(address indexed student, uint256 amount); // เหตุการณ์เมื่อนิสิตได้รับรางวัล
    event Redeemed(address indexed student, string rewardName, uint256 rewardCost, uint256 timestamp); // เหตุการณ์เมื่อนิสิตแลกรางวัล
    event LastRewardIndexChanged(uint256 newIndex);
    event RewardAdded(string name, uint256 coinCost, uint256 quantity, address rewardAddress);

    // ตัวคัดกรอง: ใช้เฉพาะเจ้าของสัญญา
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // โครงสร้างข้อมูล
    struct Reward {
        string name; // ชื่อรางวัล
        uint256 coinCost; // ราคาในการแลกรางวัล
        uint256 quantity; // ปริมาณรางวัลที่มี
        address rewardAddress; // ที่อยู่เจ้าของรางวัล
    }

    struct Redemption {
        string rewardName; // ชื่อรางวัลที่แลก
        uint256 rewardCost; // ราคาของรางวัล
        uint256 timestamp; // เวลาที่แลกรางวัล
    }

    // ฟังก์ชันที่ถูกเรียกเมื่อสัญญานี้ถูกสร้าง
    constructor() {
        owner = msg.sender; // กำหนดให้ที่อยู่ผู้ส่งเป็นเจ้าของสัญญา
    }

    // ฟังก์ชันของเจ้าของสัญญา
    function deposit() public payable onlyOwner { // ฝากเงินเข้าสัญญา
        require(msg.value > 0, "Must send some ether"); // ต้องการให้มีการส่ง ether
    }

    function rewardStudent(address student) public onlyOwner { // ให้รางวัลนิสิต
        uint256 rewardAmountEther = 0.05 ether; // จำนวนรางวัลเป็น ether
        require(address(this).balance >= rewardAmountEther, "Contract does not have enough ether to reward"); // ตรวจสอบยอดเงินในสัญญา
        payable(student).transfer(rewardAmountEther); // โอนเงินให้นิสิต
        balances[student] += rewardAmountEther; // เพิ่มยอดเงินนิสิต
        emit Rewarded(student, rewardAmountEther); // ส่งเหตุการณ์ว่านิสิตได้รับรางวัล
    }

 function addReward(string memory _name, uint256 _coinCost, uint256 _quantity) public onlyOwner {
    Reward memory newReward = Reward({
        name: _name,
        coinCost: _coinCost,
        quantity: _quantity,
        rewardAddress: owner  // ใช้ owner แทน msg.sender
    });
    rewards.push(newReward); // เพิ่มรางวัลในรายการ

    // Emit the event
    emit RewardAdded(_name, _coinCost, _quantity, owner);  // ใช้ owner แทน msg.sender
}



    function updateReward(uint256 rewardIndex, string memory newName, uint256 newCoinCost, uint256 newQuantity) public onlyOwner { // อัพเดทรางวัล
        require(rewardIndex < rewards.length, "Invalid reward index"); // ตรวจสอบ index ของรางวัล
        rewards[rewardIndex].name = newName; // เปลี่ยนชื่อรางวัล
        rewards[rewardIndex].coinCost = newCoinCost; // เปลี่ยนราคาเหรียญ
        rewards[rewardIndex].quantity = newQuantity; // เปลี่ยนปริมาณรางวัล
    }

    function deleteReward(uint256 rewardIndex) public onlyOwner { // ลบรางวัล
        require(rewardIndex < rewards.length, "Invalid reward index"); // ตรวจสอบ index ของรางวัล
        if (rewardIndex != rewards.length-1) { // ถ้าไม่ใช่รางวัลสุดท้าย
            rewards[rewardIndex] = rewards[rewards.length-1]; // ย้ายรางวัลสุดท้ายมาที่รางวัลที่จะลบ
        }
        rewards.pop(); // ลบรางวัลสุดท้าย
    }

    // ฟังก์ชันสำหรับนิสิต
    function getBalance() public view returns (uint256) { // ดึงยอดเงินของนิสิต
        return balances[msg.sender]; // แสดงยอดเงินของนิสิต
    }
 
   function getCompleteRewardData() public view returns (Reward[] memory, uint256, uint256[] memory) {
    uint256[] memory rewardIndices = new uint256[](rewards.length);
    for (uint256 i = 0; i < rewards.length; i++) {
        rewardIndices[i] = i;
    }
    uint256 lastRewardIndex = rewards.length > 0 ? rewards.length - 1 : 0;
    return (rewards, lastRewardIndex, rewardIndices);
}

function getLastRewardIndex() public view returns (uint256) {
    return rewards.length > 0 ? rewards.length - 1 : 0;
}

function emitLastRewardIndex() public {
    uint256 index = rewards.length > 0 ? rewards.length - 1 : 0;
    emit LastRewardIndexChanged(index);
}








    function redeemReward(uint256 rewardIndex) public { // นิสิตแลกรางวัล
        require(rewardIndex < rewards.length, "Invalid reward index"); // ตรวจสอบ index ของรางวัล
        Reward memory chosenReward = rewards[rewardIndex]; // ดึงรางวัลที่นิสิตเลือก
        require(balances[msg.sender] >= chosenReward.coinCost, "Not enough coins to redeem the reward"); // ตรวจสอบยอดเงินนิสิต
        require(chosenReward.quantity > 0, "Reward out of stock"); // ตรวจสอบปริมาณรางวัล
        balances[msg.sender] -= chosenReward.coinCost; // หักยอดเงินนิสิต
        balances[chosenReward.rewardAddress] += chosenReward.coinCost; // เพิ่มยอดเงินเจ้าของรางวัล
        rewards[rewardIndex].quantity--; // ลดปริมาณรางวัล
        emit Redeemed(msg.sender, chosenReward.name, chosenReward.coinCost, block.timestamp); // ส่งเหตุการณ์ว่านิสิตแลกรางวัล

        Redemption memory newRedemption = Redemption({ // บันทึกการแลกรางวัล
            rewardName: chosenReward.name,
            rewardCost: chosenReward.coinCost,
            timestamp: block.timestamp
        });
        redemptionHistory[msg.sender].push(newRedemption); // เพิ่มประวัติการแลกรางวัล
    }

    function getRedemptionHistory(address studentAddress) public view returns (Redemption[] memory) { // ดึงประวัติการแลกรางวัล
        return redemptionHistory[studentAddress]; // แสดงประวัติการแลกรางวัลของนิสิต
    }
}
