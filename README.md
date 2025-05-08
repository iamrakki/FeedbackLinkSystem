
# 📝 Feedback Link System (Smart Contract)  

**A decentralized, privacy-focused feedback management system built on Ethereum**  

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)  
[![Solidity v0.8.28](https://img.shields.io/badge/Solidity-0.8.28-blue)](https://docs.soliditylang.org/en/v0.8.28/)  

---

## 🌟 Features  
✅ **Decentralized Feedback Collection** – Create unique feedback links stored on-chain  
✅ **Privacy Controls** – Public/private link visibility (admins can restrict access)  
✅ **Topic-Based Feedback** – Each link includes a **topic + description** (stored as `bytes`)  
✅ **Admin Management** – Multiple admins with role-based access  
✅ **UUPS Upgradeable** – Contract can be upgraded securely  

---

## 📜 Contract Overview  

### **Tech Stack**  
- **Language**: Solidity `^0.8.28`  
- **Framework**: OpenZeppelin (UUPS Upgradeable)  
- **Storage**: On-chain (links, feedback, admin roles)  

### **Key Structs**  
```solidity
struct Link {
    bytes32 linkId;
    address creator;
    bytes topic;  
    bytes topicDescription;
    bool isActive;
    bool isPrivate;
    bool isDeleted;
    uint256[] feedbackIds;
}

struct Feedback {
    address author;
    bytes content;
    uint256 timestamp;
}
```

---

## 🚀 Deployment  

### **Prerequisites**  
- Node.js / npm  
- Hardhat / Foundry (for testing)  

### **Steps**  
1. Install dependencies:  
   ```bash
   npm install @openzeppelin/contracts-upgradeable
   ```
2. Deploy with **upgradeable proxy** (Hardhat example):  
   ```javascript
   const { ethers, upgrades } = require("hardhat");

   async function main() {
     const FeedbackLinkSystem = await ethers.getContractFactory("FeedbackLinkSystem");
     const feedbackSystem = await upgrades.deployProxy(FeedbackLinkSystem);
     await feedbackSystem.deployed();
     console.log("Deployed to:", feedbackSystem.address);
   }
   main();
   ```

---

## 🛠️ Usage  

### **1. Creating a Feedback Link**  
```javascript
const topic = ethers.utils.formatBytes32String("UI Feedback");
const desc = ethers.utils.formatBytes32String("Share thoughts on our new UI");
const linkName = ethers.utils.formatBytes32String("ui-feedback-2024");

await feedbackSystem.createLink(linkName, topic, desc, false); // isPrivate = false
```

### **2. Submitting Feedback**  
```javascript
const feedback = ethers.utils.formatBytes32String("Love the dark mode!");
await feedbackSystem.submitFeedback(linkId, feedback);
```

### **3. Retrieving Feedback**  
```javascript
// Get all feedback for a link
const [contents, authors, timestamps, feedbackIds] = 
  await feedbackSystem.getLinkFeedbacks(linkId);

// Get links created by an address
const [linkIds, topics, descriptions] = 
  await feedbackSystem.getLinksByCreator(userAddress);
```

---

## 🔒 Security & Permissions  

| Function | Access Control |
|----------|----------------|
| `createLink()` | Any user |
| `submitFeedback()` | Public (if link is active & not private) |
| `addAdmin()` / `removeAdmin()` | Only existing admins |
| `setLinkPrivacy()` / `deleteLink()` | Only admins |

---

## 📊 Events Emitted  

| Event | Description |
|-------|-------------|
| `LinkCreated` | New feedback link created |
| `FeedbackSubmitted` | New feedback added |
| `LinkPrivacyChanged` | Link visibility updated |
| `AdminAdded` / `AdminRemoved` | Admin roles modified |

---

## 🧪 Testing  
Run tests with:  
```bash
npx hardhat test
```

**Test Coverage:**  
- Link creation & feedback submission  
- Admin role management  
- Privacy restrictions  

---

## 📜 License  
**MIT** – Open source, free for commercial use.  

---

## ❓ FAQ  

**Q: Can feedback be modified or deleted?**  
A: No, feedback is **immutable** once submitted (but links can be deactivated).  

**Q: How are topics stored?**  
A: As `bytes` (can be strings, encoded data, etc.).  

**Q: Is this gas-efficient?**  
A: Optimized for storage, but batch operations may require high gas.  

---

**✨ Contributions welcome!** Open issues or PRs for improvements.  

--- 

Would you like me to **add anything else**, like a diagram or more detailed examples? 😊