# Privy Gas Sponsorship - Complete Setup Guide

**Date:** November 21, 2025  
**Issue:** "Insufficient funds for transfer" during borrowing  
**Status:** ⚠️ Privy Dashboard configuration required

---

## 🐛 Current Problem

**Error During Borrowing:**
```
Transaction failed: Signing failed: Expected status code 200 but got 400
The total cost (gas * gas fee + value) of executing this transaction 
exceeds the balance of the account. Details: insufficient funds for transfer
```

**Why this happens:**
- ✅ Your **code is correct** (using `wallet.provider.request()`)
- ✅ You're **omitting gas/gasPrice** (correct for sponsorship)
- ❌ **Privy Dashboard policies are NOT configured**
- ❌ Privy **rejects** the transaction (no policy match)

---

## ✅ Solution: Configure 3 Privy Policies

You need to whitelist these contracts in Privy Dashboard:

### **Policy 1: PAXG Approval (for Borrowing)** ⚠️ **REQUIRED**
### **Policy 2: USDC Approval (for Repayments)** ⚠️ **REQUIRED**
### **Policy 3: Fluid Vault Operations** ⚠️ **REQUIRED**

---

## 📋 Step-by-Step Configuration

### **Step 1: Go to Privy Dashboard**
```
URL: https://dashboard.privy.io/apps/cmhenc7hj004ijy0c311hbf2z/policies
```

1. Click **"Gas & Tx Sponsorship"** in the left sidebar
2. Click **"Policies"** tab
3. Click **"Create Policy"** button

---

### **Step 2: Create Policy 1 - PAXG Approval**

This sponsors the PAXG approval transaction when users borrow.

**Policy Details:**
```
Name: Sponsor PAXG Approval for Borrowing
Description: Allow users to approve PAXG to Fluid Vault for borrowing
Chain: Ethereum (eip155:1)
```

**Add Rule 1 (PAXG Contract):**
```
Click "Add Condition"
Field: transaction.to
Operator: equals
Value: 0x45804880De22913dAFE09f4980848ECE6EcbAf78
```

**Add Rule 2 (Approve Method):**
```
Click "Add Condition" again (same rule)
Field: transaction.data
Operator: starts_with
Value: 0x095ea7b3
```

**Set Action:**
```
Action: ALLOW
```

**Click "Save"**

**✅ Enable the policy** (toggle switch on the right)

---

### **Step 3: Create Policy 2 - USDC Approval**

This sponsors the USDC approval transaction when users repay loans.

**Policy Details:**
```
Name: Sponsor USDC Approval for Loan Repayments
Description: Allow users to approve USDC to Fluid Vault for repayments
Chain: Ethereum (eip155:1)
```

**Add Rule 1 (USDC Contract):**
```
Click "Add Condition"
Field: transaction.to
Operator: equals
Value: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
```

**Add Rule 2 (Approve Method):**
```
Click "Add Condition" again (same rule)
Field: transaction.data
Operator: starts_with
Value: 0x095ea7b3
```

**Set Action:**
```
Action: ALLOW
```

**Click "Save"**

**✅ Enable the policy** (toggle switch on the right)

---

### **Step 4: Create Policy 3 - Fluid Vault Operations**

This sponsors all Fluid vault operations (borrow, repay, withdraw, close).

**Policy Details:**
```
Name: Sponsor Fluid Vault Operations
Description: Allow all Fluid Protocol vault operations (borrow, repay, add collateral, withdraw, close)
Chain: Ethereum (eip155:1)
```

**Add Rule (Fluid Vault Contract):**
```
Click "Add Condition"
Field: transaction.to
Operator: equals
Value: 0x238207734AdBD22037af0437Ef65F13bABbd1917
```

**Set Action:**
```
Action: ALLOW
```

**Click "Save"**

**✅ Enable the policy** (toggle switch on the right)

---

## 🎯 Summary of 3 Required Policies

| Policy | Contract | Methods | Purpose |
|--------|----------|---------|---------|
| **PAXG Approval** | `0x45804880...` | `0x095ea7b3` | Approve PAXG for borrowing |
| **USDC Approval** | `0xA0b86991...` | `0x095ea7b3` | Approve USDC for repayments |
| **Fluid Vault** | `0x23820773...` | All methods | Borrow, repay, withdraw, close |

---

## 🔍 Verify Configuration

After creating the 3 policies:

### **1. Check Policy Status**
```
Go to: Privy Dashboard → Policies
Should see:
✅ Sponsor PAXG Approval for Borrowing (Enabled)
✅ Sponsor USDC Approval for Loan Repayments (Enabled)
✅ Sponsor Fluid Vault Operations (Enabled)
```

### **2. Check Policy Details**
For each policy, click and verify:
- ✅ Chain: `eip155:1` (Ethereum Mainnet)
- ✅ Status: **Enabled** (green toggle)
- ✅ Conditions match exactly
- ✅ Action: ALLOW

### **3. Check Spending Limits (Optional)**
```
Go to: Policy Settings
Daily Limit: Set to reasonable amount (e.g., $100-500)
Monthly Limit: Set to reasonable amount (e.g., $1000-5000)
```

---

## 🧪 Test After Configuration

### **Test 1: Borrow (PAXG Approval + Vault Operation)**
```
1. Open app → Go to Borrow tab
2. Enter: 0.001 PAXG, Borrow: 1 USDC
3. Tap "Execute Borrow"
4. ✅ Should see: Transaction submitted successfully
5. ✅ No "insufficient funds" error
6. ✅ Gas sponsored by Privy
```

### **Test 2: Repay Loan (USDC Approval + Vault Operation)**
```
1. Go to Loans tab
2. Expand a loan card
3. Tap "Pay Back Loan"
4. Enter: Full amount
5. Tap "Pay Back"
6. ✅ Should see: Transaction submitted successfully
7. ✅ No "insufficient funds" error
8. ✅ Gas sponsored by Privy
```

### **Test 3: Add Collateral (PAXG Approval + Vault Operation)**
```
1. Go to Loans tab
2. Tap "Add More Gold"
3. Enter: 0.0001 PAXG
4. Tap "Add Gold"
5. ✅ Should work without errors
```

---

## 📊 Expected Behavior

### **Before Configuration** ❌
```
User taps "Execute Borrow"
    ↓
Code sends transaction to Privy
    ↓
Privy checks policies
    ↓
❌ No matching policy found
    ↓
Privy rejects: "insufficient funds for transfer"
```

### **After Configuration** ✅
```
User taps "Execute Borrow"
    ↓
Code sends transaction to Privy
    ↓
Privy checks policies
    ↓
✅ Policy matches (PAXG approval or Fluid vault)
    ↓
Privy sponsors gas (user pays $0)
    ↓
Transaction succeeds! 🎉
```

---

## 🔧 Troubleshooting

### **Issue: Still getting "insufficient funds" after adding policies**

**Check 1: Policies are Enabled**
```
Go to Privy Dashboard → Policies
Each policy should have green toggle (Enabled)
If gray toggle (Disabled), click to enable
```

**Check 2: Chain is Correct**
```
All policies must be for: eip155:1 (Ethereum Mainnet)
NOT: eip155:5 (Goerli) or other testnets
```

**Check 3: Contract Addresses are Exact**
```
PAXG: 0x45804880De22913dAFE09f4980848ECE6EcbAf78 (lowercase)
USDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 (lowercase)
Fluid: 0x238207734AdBD22037af0437Ef65F13bABbd1917 (lowercase)
```

**Check 4: Method Signature is Correct**
```
For approval policies:
Field: transaction.data
Operator: starts_with
Value: 0x095ea7b3 (with 0x prefix)
```

**Check 5: Wait for Policy Propagation**
```
After creating policies, wait 1-2 minutes
Privy needs time to sync policies across their infrastructure
```

---

## 📝 Logs to Verify

**Successful Transaction (After Configuration):**
```
[AmigoGold][fluid] 🔑 Sending transaction via Privy embedded wallet with gas sponsorship
[AmigoGold][fluid] 📤 Submitting transaction via wallet.provider.request()...
[AmigoGold][fluid] ✅ Transaction submitted successfully: 0x...
[AmigoGold][fluid] 💰 Gas was sponsored by Privy (no ETH deducted from user)
```

**Failed Transaction (Policy Missing):**
```
[AmigoGold][fluid] 🔑 Sending transaction via Privy embedded wallet with gas sponsorship
[AmigoGold][fluid] 📤 Submitting transaction via wallet.provider.request()...
[AmigoGold][fluid] ❌ Transaction failed: insufficient funds for transfer
[AmigoGold][fluid] 🚨 INSUFFICIENT FUNDS ERROR - Possible causes:
[AmigoGold][fluid]    1. Gas sponsorship policy not configured in Privy Dashboard
```

---

## 💡 Important Notes

### **1. No Code Changes Needed**
Your current implementation is **100% correct**. You're using:
```swift
// ✅ CORRECT: Using embedded wallet provider
let txHash = try await wallet.provider.request(rpcRequest)

// ✅ CORRECT: Omitting gas/gasPrice for sponsorship
let unsignedTx = PrivySDK.EthereumRpcRequest.UnsignedEthTransaction(
    from: from,
    to: to,
    data: data,
    value: makeHexQuantity(value),
    chainId: .int(chainId)
    // gas: nil - Let Privy estimate
    // gasPrice: nil - Let Privy handle (will sponsor if policy matches)
)
```

### **2. Embedded Wallet vs Sponsored RPC**
Your web team mentioned "sponsorship using privy signing transactions way":
- **Embedded Wallet (iOS):** `wallet.provider.request()` - ✅ You're using this
- **Sponsored RPC (Web):** REST API with App Secret - ❌ Not recommended for mobile

You're using the **correct method for iOS**. Just need policies configured.

### **3. App Secret Not Required**
The embedded wallet method **doesn't need** the Privy App Secret exposed in the app. Sponsorship is handled server-side by Privy based on policies.

### **4. Policy Matching**
Privy matches policies based on:
- ✅ Chain ID (must be eip155:1)
- ✅ Contract address (`transaction.to`)
- ✅ Method signature (`transaction.data` starts with)
- ✅ Policy is enabled
- ✅ User is authenticated

---

## 🎯 Final Checklist

Before testing:
- [ ] Created 3 policies in Privy Dashboard
- [ ] All policies are **Enabled** (green toggle)
- [ ] Chain is set to `eip155:1` for all policies
- [ ] Contract addresses are correct (copy-pasted exactly)
- [ ] Method signatures are correct (`0x095ea7b3`)
- [ ] Waited 1-2 minutes for propagation
- [ ] Ready to test borrowing!

---

## 🚀 After Configuration

Once policies are configured:
1. ✅ **Borrowing** will work (PAXG approval + vault operation)
2. ✅ **Repayments** will work (USDC approval + vault operation)
3. ✅ **Add Collateral** will work (PAXG approval + vault operation)
4. ✅ **Withdraw** will work (vault operation only)
5. ✅ **Close Loan** will work (USDC approval + vault operation)
6. ✅ **Users pay $0 in gas** (all sponsored by Privy)

---

## 🎉 Summary

**Your Code:** ✅ Perfect (no changes needed)  
**Missing:** ⚠️ Privy Dashboard policies (3 policies)  
**Action:** Configure the 3 policies in Privy Dashboard  
**Result:** Gas sponsorship will work, no more "insufficient funds" errors  

**Configure the policies now and test borrowing!** 🚀

