# Phase 2 Completion Guide

## ✅ What's Built

### 1. Web3 Infrastructure ✅
- **`Web3Client.swift`**: Generic RPC client with automatic fallback
  - Primary RPC: Alchemy Ethereum Mainnet
  - Fallback RPC: `https://ethereum.publicnode.com`
  - Generic `eth_call` support for contract interactions
  - Error handling with retry mechanism

- **`ERC20Contract.swift`**: Token balance reader
  - Supports PAXG (18 decimals) and USDT (6 decimals)
  - Parallel balance fetching with TaskGroup
  - Automatic conversion from wei to human-readable format
  - No external dependencies (uses Decimal for large numbers)

### 2. Dashboard Updates ✅
- **`DashboardViewModel.swift`**: Business logic layer
  - Wallet connection status management
  - Live balance fetching for PAXG & USDT
  - Loading states (idle, loading, loaded, failed)
  - Error handling with user-friendly messages
  - Portfolio value calculation
  - Copy address to clipboard

- **`PerFolioDashboardView.swift`**: Enhanced UI
  - Wallet connection status card
  - Live balance display with loading states
  - Error banner with retry button
  - Copy address toast notification
  - Portfolio value in hero card

### 3. User Profile Updates ✅
- **`AGUserProfile.swift`**: Added fields
  - `walletAddress: String?` - For storing embedded wallet address
  - `lastSyncedAt: Date?` - For tracking data freshness

---

## 🚧 What Needs Configuration

### 1. Privy Dashboard - Embedded Wallet Setup
**Status:** ⚠️ REQUIRED for wallet address extraction

**Steps:**
1. Go to https://dashboard.privy.io
2. Select your app: `cmhenc7hj004ijy0c311hbf2z`
3. Navigate to **Settings > Embedded Wallets**
4. Enable: **"Create embedded wallet on login"**
5. Set: **Create for: "All users"** or **"Users without wallets"**
6. **Save changes**

**Why needed:**
- Privy will automatically create an Ethereum wallet for each user on first login
- The wallet address can then be accessed via `user.wallet.address` in Swift
- This enables the app to fetch on-chain balances

**Documentation:** https://docs.privy.io/guide/react/wallets/embedded/overview

---

### 2. Alchemy API Key
**Status:** ⚠️ REQUIRED for production RPC calls

**Current:** Using demo key `https://eth-mainnet.g.alchemy.com/v2/demo`
**Needed:** Your own Alchemy API key

**Steps:**
1. Sign up at https://alchemy.com
2. Create a new app for **Ethereum Mainnet**
3. Copy your API key
4. Update `Web3Client.swift`:

```swift
init(
    primaryRPC: String = "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY_HERE",
    fallbackRPC: String = "https://ethereum.publicnode.com",
    session: URLSession = .shared
) {
```

**Or** add to `Dev.xcconfig` / `Prod.xcconfig`:
```
ALCHEMY_API_KEY = your_key_here
```

And update `Web3Client.swift`:
```swift
let alchemyKey = Bundle.main.object(forInfoDictionaryKey: "ALCHEMY_API_KEY") as? String ?? "demo"
primaryRPC: String = "https://eth-mainnet.g.alchemy.com/v2/\(alchemyKey)"
```

**Why needed:**
- Demo key has rate limits (few requests per minute)
- Production needs unlimited requests
- Free tier: 300M compute units/month (plenty for MVP)

---

### 3. Extract Wallet Address After Auth
**Status:** ⚠️ CODE UPDATE NEEDED

**File:** `PerFolio/Features/Landing/LandingViewModel.swift`
**Function:** `verifyEmailCode(_ code: String)`

**Current code (line 74-76):**
```swift
// TODO: Extract embedded wallet address from Privy
// Requires Privy configuration: createOnLogin: "users-without-wallets"
// Will be completed after Privy dashboard configuration
```

**Replace with:**
```swift
// Extract embedded wallet address
if let embeddedWallet = user.wallet {
    let walletAddress = embeddedWallet.address
    AppLogger.log("Embedded wallet address: \(walletAddress)", category: "auth")
    
    // Save to user profile
    // TODO: Implement saveWalletAddress(walletAddress) in ProfileService
    UserDefaults.standard.set(walletAddress, forKey: "userWalletAddress")
} else {
    AppLogger.log("No embedded wallet found. Check Privy dashboard config.", category: "auth")
}
```

**Why needed:**
- Store the wallet address for later use
- Dashboard needs it to fetch balances

---

### 4. Load Wallet Address in Dashboard
**Status:** ⚠️ CODE UPDATE NEEDED

**File:** `PerFolio/Features/Tabs/PerFolioDashboardView.swift`
**Function:** `onAppear` (line 28-32)

**Current code:**
```swift
.onAppear {
    // TODO: Get wallet address from user session/profile
    // For testing, you can set a demo address:
    // viewModel.setWalletAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
}
```

**Replace with:**
```swift
.onAppear {
    // Load wallet address from storage
    if let savedAddress = UserDefaults.standard.string(forKey: "userWalletAddress") {
        viewModel.setWalletAddress(savedAddress)
    } else {
        AppLogger.log("No wallet address found in storage", category: "dashboard")
    }
}
```

**Why needed:**
- Automatically fetch balances when Dashboard appears
- Show connected wallet status

---

## 🧪 Testing Phase 2

### Manual Test Flow

1. **Login with Email**
   - Enter email → receive code → verify
   - ✅ Check logs for: `Embedded wallet address: 0x...`

2. **View Dashboard**
   - ✅ Wallet card shows "Connected" with green badge
   - ✅ Address is truncated: `0x1234...5678`
   - ✅ Copy button works (toast appears)
   - ✅ Balance rows show loading spinners

3. **Wait for Balance Load**
   - ✅ PAXG balance appears (formatted with 4 decimals)
   - ✅ USDT balance appears (formatted with 2 decimals)
   - ✅ Portfolio value updates in golden hero card

4. **Test Error Handling**
   - ✅ Turn off internet → see error banner
   - ✅ Click retry button → balances reload

### Test with Demo Wallet
For testing without real tokens:
```swift
// In PerFolioDashboardView.onAppear:
viewModel.setWalletAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
```
This Vitalik's address has PAXG/USDT balances for demo.

### Expected Logs
```
[AmigoGold][auth] Embedded wallet address: 0x...
[AmigoGold][dashboard] Wallet address set: 0x...
[AmigoGold][dashboard] Fetching balances for 0x...
[AmigoGold][web3] Fetching PAXG balance for 0x...
[AmigoGold][web3] Fetching USDT balance for 0x...
[AmigoGold][web3] PAXG balance: 1.2345
[AmigoGold][web3] USDT balance: 100.00
[AmigoGold][dashboard] Balances fetched successfully
```

---

## 📋 Phase 2 Checklist

- [ ] Configure Privy embedded wallet creation
- [ ] Add Alchemy API key
- [ ] Update `verifyEmailCode()` to save wallet address
- [ ] Update Dashboard `onAppear` to load wallet address
- [ ] Test login → wallet creation flow
- [ ] Test Dashboard balance fetching
- [ ] Test copy address feature
- [ ] Test error handling (no internet)
- [ ] Verify logs show correct wallet address
- [ ] Confirm balances display correctly

Once all items are checked, **Phase 2 is complete!** ✅

---

## 🎯 Next: Phase 3

Phase 3 will add:
- Fluid Protocol vault integration
- Borrow USDT against PAXG collateral
- Health factor calculations
- Transaction signing with embedded wallet

See `docs/perfolio_phase_plan.md` for details.

