# 📝 On-chain Petition Signing

A decentralized petition signing system built on the Stacks blockchain using Clarity smart contracts. Create, sign, and manage petitions entirely on-chain with full transparency and immutability.

## ✨ Features

- 🆕 **Create Petitions**: Launch new petitions with custom titles, descriptions, and signature thresholds
- ✍️ **Sign Petitions**: Support causes you believe in with your digital signature
- 📊 **Track Progress**: Monitor petition signatures and success rates in real-time
- ⏰ **Time-bound**: Set expiration dates for petition campaigns
- 🔒 **Secure**: Built-in protections against duplicate signatures and unauthorized actions
- 🎯 **Threshold-based**: Automatic success detection when signature goals are met

## 🚀 Quick Start

### Prerequisites

- [Clarinet CLI](https://docs.hiro.so/stacks/clarinet) installed
- Node.js for testing (optional)

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run `clarinet check` to verify the contract

## 📖 Usage

### Creating a Petition

```clarity
(contract-call? .On-chain-Petition-Signing create-petition 
  "Save the Local Park" 
  "We petition to preserve our community park from development" 
  u100  ;; signature threshold
  u1440 ;; duration in blocks (~10 days)
)
```

### Signing a Petition

```clarity
(contract-call? .On-chain-Petition-Signing sign-petition u1)
```

### Checking Petition Status

```clarity
(contract-call? .On-chain-Petition-Signing get-petition u1)
(contract-call? .On-chain-Petition-Signing get-petition-status u1)
(contract-call? .On-chain-Petition-Signing get-petition-progress u1)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-petition` | Create a new petition | title, description, threshold, duration |
| `sign-petition` | Sign an existing petition | petition-id |
| `deactivate-petition` | Deactivate your petition | petition-id |
| `reactivate-petition` | Reactivate your petition | petition-id |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-petition` | Get petition details | Petition data |
| `get-petition-status` | Get current status | "active", "expired", "successful", "inactive" |
| `get-petition-progress` | Get signature progress | Current/threshold/percentage |
| `has-signed` | Check if user signed | Boolean |
| `get-petition-signers` | Get list of signers | List of principals |
| `get-user-signatures` | Get user's signed petitions | List of petition IDs |
| `is-petition-expired` | Check expiration status | Boolean |
| `is-petition-successful` | Check success status | Boolean |

## 📊 Data Structures

### Petition
```clarity
{
  title: (string-ascii 100),
  description: (string-ascii 500),
  creator: principal,
  created-at: uint,
  expires-at: uint,
  signature-threshold: uint,
  current-signatures: uint,
  is-active: bool,
  is-successful: bool
}
```

## 🛡️ Security Features

- **Anti-spam**: Prevents duplicate signatures from the same user
- **Creator protection**: Petition creators cannot sign their own petitions
- **Time-bound**: Automatic expiration prevents indefinite campaigns
- **Access control**: Only creators can deactivate/reactivate their petitions
- **Input validation**: Checks for empty titles, descriptions, and invalid thresholds

## 🧪 Testing

Run the test suite:

```bash
npm install
npm test
```

## 📋 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Petition not found |
| u102 | Petition inactive |
| u103 | Already signed |
| u104 | Invalid threshold |
| u105 | Petition expired |
| u106 | Invalid duration |
| u107 | Empty title |
| u108 | Empty description |
| u109 | Cannot sign own petition |


## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🌟 Examples

### Community Park Petition
A local community creates a petition to save their neighborhood park from commercial development, requiring 500 signatures within 30 days.

### Policy Change Request
Citizens petition their local government for policy changes, with automatic success tracking when signature thresholds are met.

### Fundraising Initiative
Organizations use petitions to gauge community support before launching fundraising campaigns.

---

Built with ❤️ on Stacks blockchain using Clarity smart contracts.
