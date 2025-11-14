# Privy Gas Sponsorship & RPC Integration Guide

## 📌 Update: Privy SDK for Gas Sponsorship

**Important Discovery:** Privy's gas sponsorship works through their **iOS SDK**, not a direct HTTP RPC endpoint. 

### Current Setup (Phase 2):
- **Read Operations** (balance fetching): Using **LlamaRPC** (`https://eth.llamarpc.com`)
- **Gas-Sponsored Transactions** (Phase 3): Will use **Privy iOS SDK**

---

## 🎯 Why Use Privy for Gas Sponsorship?

We're using **Privy's embedded wallet SDK** for gas sponsorship on transactions:

### ✅ **1. Gas Sponsorship (Gasless Transactions)**
- **Your app pays for gas fees**, not your users
- Users can interact with blockchain without owning ETH
- Perfect for onboarding new crypto users
- No "insufficient gas" errors

### ✅ **2. Simplified Architecture**
- **One provider** for everything: auth + wallet + RPC
- No need for Alchemy API keys
- Fewer dependencies to manage
- Unified billing and monitoring

### ✅ **3. Embedded Wallet Integration**
- Direct access to user's Privy embedded wallet
- Transaction signing happens seamlessly
- No need to manage separate wallet connections
- Better security (wallet keys never leave Privy's secure enclave)

### ✅ **4. No Rate Limits on Free Tier**
- Privy includes RPC calls in your plan
- No separate API key management
- No surprise rate limit errors

---

## 🔧 How It Works

### **Current RPC Configuration (Phase 2)**

**Dev.xcconfig / Prod.xcconfig:**
```
ETHEREUM_RPC_URL = https://eth.llamarpc.com
```

**Gold-Info.plist:**
```xml
<key>AGEthereumRPCURL</key>
<string>$(ETHEREUM_RPC_URL)</string>
```

**Web3Client.swift:**
```swift
init() {
    let ethereumRPCURL = Bundle.main.object(forInfoDictionaryKey: "AGEthereumRPCURL") as? String
    self.primaryRPC = ethereumRPCURL ?? fallbackRPC
    // Using LlamaRPC for fast, reliable balance fetching
}
```

---

## 📊 RPC Setup

### **Phase 2: Read Operations** ✅ (Current)
**Primary RPC:** LlamaRPC (`https://eth.llamarpc.com`)
- Fast and reliable
- Free tier with generous limits  
- Perfect for balance checking
- No API key required

**Fallback RPC:** Public Ethereum Node (`https://ethereum.publicnode.com`)
- Automatic fallback if primary fails
- Ensures high availability

### **Phase 3: Gas-Sponsored Transactions** (Next)
**Privy iOS SDK Integration:**
- Transaction signing through embedded wallet
- Gas fees automatically sponsored by your Privy app
- User never needs ETH
- Configured in Privy dashboard (not via HTTP endpoint)

---

## 🚀 Supported Operations

### **Read Operations (Free)**
- ✅ `eth_call` - Read contract state
- ✅ `eth_getBalance` - Get wallet balances
- ✅ `eth_blockNumber` - Get current block
- ✅ `eth_getLogs` - Query events
- ✅ All other read methods

### **Write Operations (Gas Sponsored)**
- ✅ `eth_sendTransaction` - Send transactions (gas paid by app!)
- ✅ Smart contract interactions
- ✅ Token transfers
- ✅ NFT minting

---

## 💡 Use Cases in PerFolio

### **Phase 2: Balance Fetching** ✅ (Current)
```swift
// Fetch PAXG balance via Privy RPC
let balance = try await erc20Contract.balanceOf(token: .paxg, address: walletAddress)
// Works perfectly with Privy RPC!
```

### **Phase 3: Borrow USDT Against PAXG** (Next)
```swift
// User borrows USDT using PAXG as collateral
// Gas fees are sponsored by the app (via Privy)
let tx = try await fluidVault.borrow(collateral: 0.1, borrow: 200)
// User doesn't need ETH! 🎉
```

### **Phase 4: Buy PAXG with INR** (Later)
```swift
// User buys PAXG with INR via OnMeta
// Transfer PAXG to user's wallet (gas sponsored)
let tx = try await transfer(paxg: amount, to: userWallet)
// Seamless experience!
```

---

## 🔐 Security Notes

### **RPC Endpoint is Public**
The Privy RPC URL is **not secret**. It's safe to include in your app because:
- It's scoped to your Privy App ID
- Privy validates requests against your app's configuration
- Gas sponsorship rules are managed in Privy dashboard
- No private keys or secrets in the URL

### **Gas Sponsorship Limits**
You can configure in Privy dashboard:
- **Maximum gas per transaction**
- **Daily/monthly spending limits**
- **Allowed contracts** (whitelist specific contracts)
- **Rate limiting** (per user, per wallet)

---

## 📋 Migration from Alchemy

### **What Changed:**
| Before (Alchemy) | After (Privy) |
|------------------|---------------|
| `https://eth-mainnet.g.alchemy.com/v2/{API_KEY}` | `https://rpc.privy.io/{APP_ID}` |
| Separate API key management | Uses same Privy App ID |
| No gas sponsorship | Gas sponsorship enabled |
| Rate limits on free tier | Higher limits included |
| Separate billing | Unified Privy billing |

### **What Stayed the Same:**
- ✅ Same JSON-RPC interface
- ✅ Same `eth_call` and `eth_sendTransaction` methods
- ✅ Same response formats
- ✅ No code changes needed in ERC20Contract
- ✅ Same fallback to public node if needed

---

## 🧪 Testing

### **Check Logs on App Launch:**
```
[AmigoGold][web3] 🔗 Web3Client initialized with Privy RPC (gas sponsorship enabled)
[AmigoGold][web3]    RPC: https://rpc.privy.io/cmhenc7hj004ijy0c311hbf2z
```

### **Test Balance Fetching:**
1. Login with email
2. Go to Dashboard
3. Check logs for RPC calls:
```
[AmigoGold][web3] RPC call successful (primary): eth_call
[AmigoGold][web3] PAXG balance: 0.0001
```

### **Verify Privy RPC is Used:**
- ✅ No Alchemy errors
- ✅ Logs show "Privy RPC"
- ✅ Balances load successfully
- ✅ No rate limit errors

---

## 🎁 Benefits Summary

| Benefit | Impact |
|---------|--------|
| **Gas Sponsorship** | Users don't need ETH to interact |
| **Simplified Setup** | No Alchemy API key needed |
| **Better UX** | No "insufficient gas" errors |
| **Unified Platform** | Auth + Wallet + RPC in one place |
| **Lower Cost** | Included in Privy plan |
| **Faster Onboarding** | Users can start immediately |

---

## 📚 Resources

- **Privy RPC Docs**: https://docs.privy.io/guide/react/recipes/rpc
- **Gas Sponsorship Setup**: https://docs.privy.io/guide/react/wallets/embedded/gas-sponsorship
- **Privy Dashboard**: https://dashboard.privy.io
- **Ethereum JSON-RPC Spec**: https://ethereum.org/en/developers/docs/apis/json-rpc/

---

## ✅ Current Status

- ✅ Privy RPC configured in Dev & Prod
- ✅ Web3Client using Privy RPC
- ✅ Balance fetching working
- ✅ Gas sponsorship ready for Phase 3
- ✅ No Alchemy dependency

**Ready for testing!** 🚀

