# PerFolio - Master Project Specification
**Version:** 1.0  
**Last Updated:** November 2024  
**Platform:** iOS (Swift/SwiftUI) | Android (TBD)

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Core Features](#core-features)
4. [Technical Stack](#technical-stack)
5. [Smart Contracts](#smart-contracts)
6. [Third-Party Integrations](#third-party-integrations)
7. [Data Models](#data-models)
8. [Business Logic & Calculations](#business-logic--calculations)
9. [UI/UX Patterns](#uiux-patterns)
10. [Security & Authentication](#security--authentication)
11. [Testing Strategy](#testing-strategy)
12. [Deployment & CI/CD](#deployment--cicd)
13. [Android Implementation Guide](#android-implementation-guide)

---

## 📱 Project Overview

### What is PerFolio?

PerFolio is a **decentralized finance (DeFi) mobile application** that enables users to:
- 💰 **Deposit & Buy:** Purchase crypto using INR (Indian Rupees) via fiat on-ramps
- 🪙 **Swap:** Convert USDC to PAXG (tokenized gold) using decentralized exchanges
- 🏦 **Borrow:** Take loans against PAXG collateral using Fluid Protocol
- 📊 **Manage:** Track and manage active loan positions
- 💸 **Withdraw:** Cash out crypto to bank accounts (off-ramp)

### Key Principles

1. **No Backend Database** - All data fetched directly from Ethereum blockchain via RPC
2. **Smart Contracts as Backend** - Fluid Protocol contracts handle all loan logic
3. **Embedded Wallet UX** - Privy SDK provides seamless wallet experience
4. **Mobile-First** - Native iOS app with planned Android version
5. **RPC-First Architecture** - Direct blockchain interaction without intermediary servers

### Target Users

- Indian users wanting to invest in digital gold (PAXG)
- Users seeking instant loans against crypto collateral
- DeFi users looking for mobile-first experience
- Users preferring embedded wallets over external wallet connections

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Mobile App (SwiftUI)                   │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐  │
│  │Dashboard │  Wallet  │  Borrow  │  Loans   │ Settings │  │
│  └────┬─────┴─────┬────┴─────┬────┴─────┬────┴────┬─────┘  │
│       │           │          │          │         │         │
└───────┼───────────┼──────────┼──────────┼─────────┼─────────┘
        │           │          │          │         │
        ▼           ▼          ▼          ▼         ▼
┌─────────────────────────────────────────────────────────────┐
│                     Service Layer                            │
│  ┌──────────────┬──────────────┬──────────────────────────┐ │
│  │ Web3Client   │ ERC20Contract│ FluidVaultService        │ │
│  │ (RPC)        │              │ FluidPositionsService    │ │
│  └──────┬───────┴──────┬───────┴──────┬───────────────────┘ │
└─────────┼──────────────┼──────────────┼──────────────────────┘
          │              │              │
          ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│              Ethereum Mainnet (via RPC)                      │
│  ┌──────────────┬──────────────┬──────────────────────────┐ │
│  │ Alchemy RPC  │ Public Node  │ Smart Contracts          │ │
│  │ (Primary)    │ (Fallback)   │ • PAXG Token             │ │
│  │              │              │ • USDC Token             │ │
│  │              │              │ • Fluid Vault            │ │
│  │              │              │ • Fluid Resolver         │ │
│  └──────────────┴──────────────┴──────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              External Services (Widgets)                     │
│  ┌──────────────┬──────────────┬──────────────────────────┐ │
│  │ Privy SDK    │ OnMeta       │ Transak                  │ │
│  │ (Auth +      │ (Fiat        │ (Fiat                    │ │
│  │  Wallet)     │  On-ramp)    │  Off-ramp)               │ │
│  └──────────────┴──────────────┴──────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Layer Breakdown

#### **1. Presentation Layer (SwiftUI Views)**
- `BorrowView`, `ActiveLoansView`, `DepositBuyView`, `WithdrawView`
- Reactive UI using `@Published` properties
- Native iOS components with custom gold theme

#### **2. ViewModel Layer**
- `BorrowViewModel`, `ActiveLoansViewModel`, etc.
- Business logic and state management
- Combines user input with service responses
- Publishes UI updates via Combine framework

#### **3. Service Layer**
- **Web3Client**: Generic RPC client with fallback
- **ERC20Contract**: Token balance and approval operations
- **FluidVaultService**: Borrow, repay, collateral management
- **FluidPositionsService**: Fetch user's active loan positions
- **VaultConfigService**: Fetch vault parameters
- **PriceOracleService**: Fetch PAXG price
- **DEXSwapService**: 0x API integration for swaps
- **OnMetaService**: Fiat on-ramp integration
- **TransakService**: Fiat off-ramp integration

#### **4. Blockchain Layer**
- Ethereum Mainnet (Chain ID: 1)
- Smart contracts (ERC-20, Fluid Protocol)
- RPC endpoints (Alchemy + public fallback)

### Data Flow Example (Borrow Transaction)

```
User Input (Collateral + Borrow Amount)
    ↓
BorrowViewModel.executeBorrow()
    ↓
FluidVaultService.executeBorrow(request)
    ├─ Step 1: Check PAXG Allowance (RPC eth_call)
    ├─ Step 2: Approve PAXG if needed (Privy sign + RPC eth_sendTransaction)
    └─ Step 3: Execute operate() (Privy sign + RPC eth_sendTransaction)
    ↓
Wait for Transaction Confirmation
    ↓
FluidPositionsService.fetchPositions()
    ↓
Display Updated Position in Active Loans Tab
```

---

## 🎯 Core Features

### Feature 1: Borrow (Collateralized Loans)

**Description:** Users deposit PAXG (tokenized gold) as collateral to borrow USDC (stablecoin).

**User Flow:**
1. Navigate to "Borrow" tab
2. Enter collateral amount (PAXG)
3. Enter borrow amount (USDC)
4. View real-time risk metrics (LTV, Health Factor, Liquidation Price)
5. Click "BORROW USDC"
6. Sign approval transaction (if needed)
7. Sign borrow transaction
8. Receive USDC + NFT position created

**Technical Implementation:**

**Files:**
- `BorrowView.swift` (530 lines) - Main UI
- `BorrowViewModel.swift` (280 lines) - Business logic
- `TransactionProgressView.swift` (240 lines) - Transaction modal
- `APYChartView.swift` (260 lines) - APY history chart
- `FluidVaultService.swift` (918 lines) - Core service

**Key Calculations:**
```swift
// Maximum borrowable amount
maxBorrow = collateralValue × maxLTV
maxBorrow = (collateral × paxgPrice) × 0.75

// Health Factor
healthFactor = (collateralValue × liquidationThreshold) / debtValue
healthFactor = (collateral × price × 0.85) / borrowAmount

// Current LTV
currentLTV = (debtValue / collateralValue) × 100
currentLTV = (borrowAmount / (collateral × price)) × 100

// Liquidation Price
liquidationPrice = debtValue / (collateral × liquidationThreshold)
liquidationPrice = borrowAmount / (collateral × 0.85)
```

**Smart Contract Integration:**
```solidity
// Fluid Vault Contract: 0x238207734AdBD22037af0437Ef65F13bABbd1917
function operate(
    uint256 nftId_,        // 0 for new position
    int256 newCol_,        // Collateral change (positive = deposit)
    int256 newDebt_,       // Debt change (positive = borrow)
    address to_            // Recipient address for borrowed funds
) external payable;
```

**RPC Calls:**
1. `eth_call` to check PAXG allowance
2. `eth_sendTransaction` for PAXG approval (if needed)
3. `eth_sendTransaction` for operate() call
4. `eth_call` to fetch updated position

**Risk Parameters:**
- Max LTV: 75%
- Liquidation Threshold: 85%
- Safe Health Factor: > 1.5
- Warning Health Factor: 1.2 - 1.5
- Danger Health Factor: < 1.2

---

### Feature 2: Active Loans (Position Management)

**Description:** View and manage all active loan positions

**User Flow:**
1. Navigate to "Loans" tab
2. View list of active positions
3. Select a position to see details
4. Perform actions:
   - Add More Collateral (improve health)
   - Pay Back Loan (reduce debt)
   - Take Gold Back (withdraw excess collateral)
   - Close Loan (repay all debt + withdraw all collateral)

**Technical Implementation:**

**Files:**
- `ActiveLoansView.swift` (450 lines) - Main UI
- `ActiveLoansViewModel.swift` (180 lines) - Business logic
- `LoanActionHandler.swift` (220 lines) - Action orchestration
- `LoanActionSheet.swift` (290 lines) - Action input modal
- `FluidPositionsService.swift` (180 lines) - Position fetching

**Data Source:**
```solidity
// Fluid Vault Resolver: 0x394Ce45678e0019c0045194a561E2bEd0FCc6Cf0
function positionsByUser(address user) 
    external view 
    returns (UserPosition[] memory positions);
```

**Position Data Structure:**
```swift
struct BorrowPosition {
    let id: String              // Unique ID
    let nftId: String           // Position NFT ID
    let owner: String           // User's wallet address
    let vaultAddress: String    // Fluid vault address
    let collateralAmount: Decimal    // PAXG deposited
    let borrowAmount: Decimal        // USDC borrowed
    let collateralValueUSD: Decimal  // Collateral in USD
    let debtValueUSD: Decimal        // Debt in USD
    let healthFactor: Decimal        // Risk metric
    let currentLTV: Decimal          // Loan-to-value %
    let liquidationPrice: Decimal    // Price at which liquidation occurs
    let availableToBorrowUSD: Decimal // Remaining borrow capacity
    let status: PositionStatus       // safe, warning, danger
}
```

**Actions:**

1. **Add Collateral:**
```swift
// Increases collateral → improves health factor
operate(nftId, +collateralDelta, 0, userAddress)
```

2. **Repay Debt:**
```swift
// Decreases debt → improves health factor
// Requires USDC approval first
operate(nftId, 0, -debtDelta, userAddress)
```

3. **Withdraw Collateral:**
```swift
// Decreases collateral → worsens health factor
// Only allowed if health factor remains > 1.5
operate(nftId, -collateralDelta, 0, userAddress)
```

4. **Close Position:**
```swift
// Repay all debt + withdraw all collateral
operate(nftId, -totalCollateral, -totalDebt, userAddress)
```

---

### Feature 3: Wallet (Deposit, Swap, Withdraw)

**Description:** Manage crypto assets - buy, swap, and cash out

#### 3A. Deposit (Fiat On-Ramp)

**User Flow:**
1. Navigate to "Wallet" tab → "Deposit" section
2. Enter INR amount to deposit
3. Select payment method (UPI/Bank/Card)
4. Click "BUY NOW"
5. OnMeta widget opens in browser
6. Complete payment
7. USDC credited to wallet

**Technical Implementation:**

**Files:**
- `DepositBuyView.swift` (600 lines) - Wallet tab UI
- `DepositBuyViewModel.swift` (350 lines) - Business logic
- `OnMetaService.swift` (150 lines) - On-ramp integration

**OnMeta Widget URL:**
```
https://platform.onmeta.in/
  ?apiKey=<ONMETA_API_KEY>
  &walletAddress=<user_wallet>
  &fiatAmount=<amount_inr>
  &tokenSymbol=USDC
  &fiatType=INR
  &chainId=1
  &offRamp=disabled
```

**Integration:**
- Opens in `SFSafariViewController`
- User completes payment in browser
- Returns to app after transaction
- Balance refreshed automatically

#### 3B. Swap (USDC → PAXG)

**User Flow:**
1. Navigate to "Wallet" tab → "Swap" section
2. Enter USDC amount to swap
3. View PAXG amount you'll receive
4. View swap route and fees
5. Click "SWAP NOW"
6. Sign approval (if needed)
7. Sign swap transaction
8. PAXG credited to wallet

**Technical Implementation:**

**Files:**
- `DEXSwapService.swift` (560 lines) - 0x API integration

**0x API Integration:**
```
GET https://api.0x.org/swap/v1/quote
  ?sellToken=USDC
  &buyToken=PAXG
  &sellAmount=<amount_in_wei>
  &takerAddress=<user_wallet>
  &slippagePercentage=0.01
```

**Transaction Flow:**
1. Get quote from 0x API
2. Check USDC allowance to 0x proxy
3. Approve USDC if needed (Privy sign)
4. Execute swap (Privy sign)
5. PAXG received

**Minimum Swap Amount:** 10 USDC (prevents "no route" errors)

#### 3C. Withdraw (Fiat Off-Ramp)

**User Flow:**
1. Navigate to "Wallet" tab → "Withdraw" section
2. Enter USDC amount to withdraw
3. View INR amount you'll receive
4. Click "START WITHDRAWAL"
5. Transak widget opens
6. Complete KYC (if needed)
7. Provide bank details
8. INR transferred to bank account

**Technical Implementation:**

**Files:**
- `WithdrawView.swift` (integrated in DepositBuyView)
- `WithdrawViewModel.swift` (200 lines) - Business logic
- `TransakService.swift` (200 lines) - Off-ramp integration

**Transak Widget URL:**
```
https://global.transak.com/
  ?apiKey=<TRANSAK_API_KEY>
  &walletAddress=<user_wallet>
  &cryptoAmount=<amount_usdc>
  &cryptoCurrencyCode=USDC
  &fiatCurrency=INR
  &network=ethereum
  &productsAvailed=SELL
```

**Minimum Withdrawal:** 10 USDC

---

## 🛠️ Technical Stack

### iOS Implementation

#### **Core Technologies**
- **Language:** Swift 6.0
- **UI Framework:** SwiftUI (iOS 18+)
- **Concurrency:** async/await, Actors
- **Reactive:** Combine framework
- **Persistence:** UserDefaults (wallet address only)
- **Package Manager:** Swift Package Manager (SPM)

#### **Key Dependencies**

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/privy-io/privy-ios",
        branch: "main"
    )
]
```

**Privy SDK:**
- Version: Latest from main branch
- Purpose: Authentication + Embedded Wallet + Transaction Signing
- Features: Email login, embedded wallet creation, gas sponsorship

#### **Xcode Configuration**
- **Xcode Version:** 16.0+
- **iOS Deployment Target:** 18.6
- **Swift Version:** 6.0
- **App ID:** `cmhvskgil00nvky0cb6rjejrs`
- **Client ID:** `client-WY6SX56F52MtzFqDzgL6jxdNAfpyL3kdY77zMdG4FgS2J`

#### **Environment Configuration**

**Dev.xcconfig:**
```
APP_ENVIRONMENT = development
PRIVY_APP_ID = cmhvskgil00nvky0cb6rjejrs
PRIVY_APP_CLIENT_ID = client-WY6SX56F52MtzFqDzgL6jxdNAfpyL3kdY77zMdG4FgS2J
ALCHEMY_API_KEY = <your_alchemy_key>
ETHEREUM_RPC_FALLBACK = https://ethereum.publicnode.com
ZEROX_API_KEY = <your_0x_key>
ONMETA_API_KEY = <your_onmeta_key>
TRANSAK_API_KEY = <your_transak_key>
ENABLE_PRIVY_SPONSORED_RPC = YES
```

---

## 📜 Smart Contracts

### Contract Addresses (Ethereum Mainnet)

```swift
// ContractAddresses.swift
enum ContractAddresses {
    // ERC-20 Tokens
    static let paxg = "0x45804880De22913dAFE09f4980848ECE6EcbAf78"
    static let usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    static let usdt = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    
    // Fluid Protocol
    static let fluidPaxgUsdcVault = "0x238207734AdBD22037af0437Ef65F13bABbd1917"
    static let fluidVaultResolver = "0x394Ce45678e0019c0045194a561E2bEd0FCc6Cf0"
    static let fluidPositionsResolver = "0x3E3dae4F30347782089d398D462546eb5276801C"
    static let fluidLendingResolver = "0x123..." // APY data
}
```

### ABI Function Signatures

#### **ERC-20 Standard**
```solidity
// Function: balanceOf(address)
Selector: 0x70a08231
Parameters: address (padded to 32 bytes)
Returns: uint256 (balance in wei)

// Function: allowance(address owner, address spender)
Selector: 0xdd62ed3e
Parameters: address owner, address spender
Returns: uint256 (allowance in wei)

// Function: approve(address spender, uint256 amount)
Selector: 0x095ea7b3
Parameters: address spender, uint256 amount
Returns: bool (success)
```

#### **Fluid Vault**
```solidity
// Function: operate(uint256 nftId, int256 newCol, int256 newDebt, address to)
Selector: 0x25...  // Full selector from Fluid docs
Parameters:
  - nftId: Position NFT ID (0 for new position)
  - newCol: Collateral change in wei (positive = deposit, negative = withdraw)
  - newDebt: Debt change in wei (positive = borrow, negative = repay)
  - to: Address to send borrowed funds
Returns: NFT ID (for new positions)
```

#### **Fluid Vault Resolver**
```solidity
// Function: getVaultEntireData(address vault)
Selector: 0x09c062e2
Parameters: address vault
Returns: Struct with vault configuration

// Function: positionsByUser(address user)
Selector: 0x347ca8bb
Parameters: address user
Returns: Array of position structs
```

### ABI Encoding Examples

```swift
// Example 1: balanceOf(address)
let functionSelector = "0x70a08231"
let addressParam = userAddress.dropFirst(2) // Remove "0x"
    .paddingToLeft(upTo: 64, using: "0") // Pad to 32 bytes (64 hex chars)
let callData = functionSelector + addressParam

// Example 2: approve(address, uint256)
let functionSelector = "0x095ea7b3"
let spender = spenderAddress.dropFirst(2).paddingToLeft(upTo: 64, using: "0")
let amount = String(amountInWei, radix: 16).paddingToLeft(upTo: 64, using: "0")
let callData = functionSelector + spender + amount
```

---

## 🔌 Third-Party Integrations

### 1. Privy SDK (Authentication + Wallet)

**Purpose:** User authentication and embedded wallet management

**Configuration:**
```swift
// PrivyAuthCoordinator.swift
PrivySDK.Configuration(
    appId: "cmhvskgil00nvky0cb6rjejrs",
    clientId: "client-WY6SX56F52MtzFqDzgL6jxdNAfpyL3kdY77zMdG4FgS2J",
    appearance: .init(
        theme: .dark,
        accentColor: UIColor(red: 0.82, green: 0.69, blue: 0.44, alpha: 1.0) // Gold
    ),
    loginMethods: [.email],
    embeddedWalletConfig: .init(
        createOnLogin: .usersWithoutWallets,
        showWalletUIs: false
    )
)
```

**Key Features:**
- Email-only login (OTP verification)
- Automatic embedded wallet creation
- Transaction signing via `wallet.provider.request()`
- Gas sponsorship via dashboard policies

**Gas Sponsorship Setup:**

**Policy 1: PAXG Approval for Borrowing**
- Chain: Ethereum (eip155:1)
- Condition: `transaction.to = 0x45804880De22913dAFE09f4980848ECE6EcbAf78`
- Action: ALLOW

**Policy 2: USDC Approval for Repayments**
- Chain: Ethereum (eip155:1)
- Condition: `transaction.to = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
- Action: ALLOW

**Policy 3: Fluid Vault Operations**
- Chain: Ethereum (eip155:1)
- Condition: `transaction.to = 0x238207734AdBD22037af0437Ef65F13bABbd1917`
- Action: ALLOW

**Note:** Privy Smart Wallets are NOT available for native iOS Swift SDK. Only embedded wallets are supported.

---

### 2. Alchemy (RPC Provider)

**Purpose:** Primary Ethereum mainnet RPC endpoint

**Endpoint:**
```
https://eth-mainnet.g.alchemy.com/v2/<ALCHEMY_API_KEY>
```

**Usage:**
- All `eth_call` requests (read operations)
- All `eth_sendTransaction` requests (write operations)
- Block number queries
- Transaction status checks

**Fallback:** `https://ethereum.publicnode.com`

---

### 3. 0x API (DEX Aggregator)

**Purpose:** Get best swap prices across multiple DEXs

**Endpoint:**
```
https://api.0x.org/swap/v1/quote
```

**Headers:**
```
0x-api-key: <ZEROX_API_KEY>
```

**Request Example:**
```
GET /swap/v1/quote
  ?sellToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  // USDC
  &buyToken=0x45804880De22913dAFE09f4980848ECE6EcbAf78   // PAXG
  &sellAmount=1000000000  // 1000 USDC (6 decimals)
  &takerAddress=0x...     // User wallet
  &slippagePercentage=0.01
```

**Response:**
```json
{
  "price": "0.000241",  // PAXG per USDC
  "guaranteedPrice": "0.000240",
  "to": "0x...",  // 0x Exchange Proxy address
  "data": "0x...",  // Transaction data
  "value": "0",
  "gas": "150000",
  "estimatedGas": "145234",
  "gasPrice": "25000000000",
  "protocolFee": "0",
  "minimumProtocolFee": "0",
  "buyAmount": "241000000000000000",  // 0.241 PAXG (18 decimals)
  "sellAmount": "1000000000",
  "sources": [
    {
      "name": "Uniswap_V3",
      "proportion": "1"
    }
  ]
}
```

**Minimum Amount:** 10 USDC (to ensure liquidity routing)

---

### 4. OnMeta (Fiat On-Ramp)

**Purpose:** INR to USDC conversion

**Widget URL:**
```
https://platform.onmeta.in/
  ?apiKey=<ONMETA_API_KEY>
  &walletAddress=<user_wallet>
  &fiatAmount=<amount_inr>
  &tokenSymbol=USDC
  &fiatType=INR
  &chainId=1
  &offRamp=disabled
```

**Integration:**
- Open in SFSafariViewController
- User completes payment
- OnMeta handles KYC/payment processing
- USDC credited directly to user wallet

**Supported Payment Methods:**
- UPI
- Bank Transfer
- Debit/Credit Cards

---

### 5. Transak (Fiat Off-Ramp)

**Purpose:** USDC to INR bank transfer

**Widget URL:**
```
https://global.transak.com/
  ?apiKey=<TRANSAK_API_KEY>
  &walletAddress=<user_wallet>
  &cryptoAmount=<amount_usdc>
  &cryptoCurrencyCode=USDC
  &fiatCurrency=INR
  &network=ethereum
  &productsAvailed=SELL
  &themeColor=D4AF37
  &hideMenu=true
  &disableWalletAddressForm=true
  &redirectURL=perfolio://transak-complete
```

**Features:**
- KYC verification
- Bank account verification
- Processing time: 1-2 business days
- Minimum: 10 USDC

---

## 📊 Data Models

### Core Models

```swift
// BorrowPosition.swift
struct BorrowPosition: Identifiable, Codable {
    let id: String
    let nftId: String
    let owner: String
    let vaultAddress: String
    let collateralAmount: Decimal
    let borrowAmount: Decimal
    let collateralValueUSD: Decimal
    let debtValueUSD: Decimal
    let healthFactor: Decimal
    let currentLTV: Decimal
    let liquidationPrice: Decimal
    let availableToBorrowUSD: Decimal
    let status: PositionStatus
    let createdAt: Date
    let lastUpdatedAt: Date
    
    enum PositionStatus: String, Codable {
        case safe       // Health > 1.5
        case warning    // Health 1.2-1.5
        case danger     // Health < 1.2
    }
}

// VaultConfig.swift
struct VaultConfig: Codable {
    let vaultAddress: String
    let collateralToken: String   // "PAXG"
    let debtToken: String          // "USDC"
    let maxLTV: Decimal            // 75.0 (%)
    let liquidationThreshold: Decimal  // 85.0 (%)
    let liquidationPenalty: Decimal    // 3.0 (%)
    let borrowRate: Decimal        // Current APY
    let supplyRate: Decimal
    let lastUpdated: Date
}

// BorrowRequest.swift
struct BorrowRequest {
    let collateralAmount: Decimal
    let borrowAmount: Decimal
    let userAddress: String
    let vaultAddress: String
    
    var collateralAmountInWei: String {
        // Convert to wei (18 decimals for PAXG)
    }
    
    var borrowAmountInWei: String {
        // Convert to wei (6 decimals for USDC)
    }
}

// BorrowMetrics.swift
struct BorrowMetrics {
    let collateralAmount: Decimal
    let borrowAmount: Decimal
    let collateralValueUSD: Decimal
    let currentLTV: Decimal
    let maxBorrowableUSD: Decimal
    let healthFactor: Decimal
    let liquidationPrice: Decimal
    let isValid: Bool
    let warnings: [String]
}

// TokenBalance.swift
struct TokenBalance {
    let address: String
    let symbol: String
    let decimals: Int
    let rawBalance: String      // Hex string
    let formattedBalance: String  // "0.1234 PAXG"
    let decimalBalance: Decimal
}
```

---

## 🧮 Business Logic & Calculations

### Loan Calculations

```swift
// BorrowCalculationEngine.swift

// 1. Maximum Borrowable Amount
func calculateMaxBorrow(
    collateral: Decimal,
    price: Decimal,
    maxLTV: Decimal  // e.g., 75%
) -> Decimal {
    let collateralValue = collateral * price
    return collateralValue * (maxLTV / 100)
}

// 2. Health Factor
func calculateHealthFactor(
    collateral: Decimal,
    price: Decimal,
    debt: Decimal,
    liquidationThreshold: Decimal  // e.g., 85%
) -> Decimal {
    guard debt > 0 else { return .greatestFiniteMagnitude }
    let collateralValue = collateral * price
    let adjustedCollateral = collateralValue * (liquidationThreshold / 100)
    return adjustedCollateral / debt
}

// 3. Current LTV
func calculateCurrentLTV(
    collateral: Decimal,
    price: Decimal,
    debt: Decimal
) -> Decimal {
    let collateralValue = collateral * price
    guard collateralValue > 0 else { return 0 }
    return (debt / collateralValue) * 100
}

// 4. Liquidation Price
func calculateLiquidationPrice(
    collateral: Decimal,
    debt: Decimal,
    liquidationThreshold: Decimal  // e.g., 85%
) -> Decimal {
    guard collateral > 0 else { return 0 }
    return debt / (collateral * (liquidationThreshold / 100))
}

// 5. Available to Borrow
func calculateAvailableToBorrow(
    collateral: Decimal,
    price: Decimal,
    currentDebt: Decimal,
    maxLTV: Decimal
) -> Decimal {
    let maxBorrow = calculateMaxBorrow(
        collateral: collateral,
        price: price,
        maxLTV: maxLTV
    )
    return max(0, maxBorrow - currentDebt)
}

// 6. Risk Status
func determineRiskStatus(healthFactor: Decimal) -> PositionStatus {
    if healthFactor > 1.5 {
        return .safe
    } else if healthFactor >= 1.2 {
        return .warning
    } else {
        return .danger
    }
}
```

### Wei Conversion

```swift
// Convert decimal amount to wei (18 decimals for PAXG)
func toWei18(_ amount: Decimal) -> String {
    let multiplier = Decimal(string: "1000000000000000000")! // 10^18
    let weiAmount = amount * multiplier
    return String(describing: weiAmount)
}

// Convert decimal amount to wei (6 decimals for USDC)
func toWei6(_ amount: Decimal) -> String {
    let multiplier = Decimal(string: "1000000")! // 10^6
    let weiAmount = amount * multiplier
    return String(describing: weiAmount)
}

// Convert wei string to decimal (18 decimals)
func fromWei18(_ wei: String) -> Decimal {
    guard let value = Decimal(string: wei) else { return 0 }
    let divisor = Decimal(string: "1000000000000000000")!
    return value / divisor
}

// Convert wei string to decimal (6 decimals)
func fromWei6(_ wei: String) -> Decimal {
    guard let value = Decimal(string: wei) else { return 0 }
    let divisor = Decimal(string: "1000000")!
    return value / divisor
}
```

---

## 🎨 UI/UX Patterns

### Theme System

```swift
// PerFolioTheme.swift
struct PerFolioTheme {
    // Background Colors
    let primaryBackground = Color(hex: "1D1D1D")     // RGB(29,29,29)
    let secondaryBackground = Color(hex: "242424")   // Card backgrounds
    
    // Gold Accent Colors
    let tintColor = Color(hex: "D0B070")             // Primary gold
    let buttonBackground = Color(hex: "9D7618")      // Button gold
    let goldenGradient = LinearGradient(
        colors: [Color(hex: "D0B070"), Color(hex: "B88A3C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Status Colors
    let success = Color.green
    let warning = Color.orange
    let danger = Color.red
    
    // Text Colors
    let primaryText = Color.white
    let secondaryText = Color.gray
}
```

### Component Library

**PerFolioCard:**
```swift
struct PerFolioCard<Content: View>: View {
    let content: Content
    
    var body: some View {
        content
            .padding()
            .background(theme.secondaryBackground)
            .cornerRadius(16)
            .shadow(radius: 4)
    }
}
```

**PerFolioButton:**
```swift
struct PerFolioButton: View {
    let title: String
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDisabled ? Color.gray : theme.buttonBackground)
                .cornerRadius(12)
        }
        .disabled(isDisabled)
    }
}
```

**PerFolioInputField:**
```swift
struct PerFolioInputField: View {
    @Binding var text: String
    let label: String
    let trailingText: String?
    let presetValues: [String]
    let onPresetTap: ((String) -> Void)?
    
    // Implementation with preset buttons
}
```

### Loading States

```swift
enum ViewState: Equatable {
    case loading
    case ready
    case error(String)
}

// Usage in ViewModels
@Published var viewState: ViewState = .loading

// In Views
switch viewModel.viewState {
case .loading:
    ProgressView("Loading...")
case .ready:
    // Show content
case .error(let message):
    ErrorView(message: message, retry: { })
}
```

---

## 🔐 Security & Authentication

### Privy Authentication Flow

```
1. App Launch
    ↓
2. Check Privy Session
    ├─ If valid → Navigate to Dashboard
    └─ If invalid → Show Login Screen
    ↓
3. User Enters Email
    ↓
4. Privy Sends OTP
    ↓
5. User Enters OTP
    ↓
6. Privy Verifies OTP
    ↓
7. Create/Load Embedded Wallet
    ↓
8. Store Wallet Address (UserDefaults)
    ↓
9. Navigate to Dashboard
```

### Transaction Signing

```swift
// All transactions signed via Privy SDK
func sendPrivyTransaction(_ request: TransactionRequest) async throws -> String {
    guard let privyWallet = privy.user?.wallet else {
        throw Error.noWallet
    }
    
    // Create unsigned transaction
    let unsignedTx = EthereumRpcRequest.UnsignedEthTransaction(
        from: request.from,
        to: request.to,
        data: request.data,
        value: request.value,
        chainId: .int(1),  // Ethereum mainnet
        gas: nil,          // Let Privy estimate
        gasPrice: nil      // Let Privy handle (gas sponsorship)
    )
    
    // Sign and send via Privy
    let rpcRequest = try EthereumRpcRequest.ethSendTransaction(
        transaction: unsignedTx
    )
    
    return try await privyWallet.provider.request(rpcRequest)
}
```

### Gas Sponsorship

**How it works:**
1. App sends transaction via Privy SDK
2. Privy checks dashboard policies
3. If policy matches, Privy sponsors gas
4. Transaction executed without user paying gas

**Policy Configuration:**
- Must be set up in Privy Dashboard
- Cannot be configured via SDK for native iOS
- Policies match on `transaction.to` address

---

## 🧪 Testing Strategy

### Test Coverage

**Critical Tests (✅ Implemented):**
1. `FluidVaultServiceTests` (38 tests)
   - Borrow transaction flow
   - Approval checks
   - Loan operations (repay, add collateral, withdraw, close)
   - Balance validations
   - Error handling

2. `BorrowViewModelTests` (35 tests)
   - Initial data loading
   - Metric calculations
   - Quick actions
   - Input validation
   - Transaction states

3. `ActiveLoansViewModelTests` (15 tests)
   - Position loading
   - Summary calculations
   - State management

4. `LoanActionHandlerTests` (20 tests)
   - All 4 loan actions
   - Error scenarios

5. `BorrowPositionTests` (12 tests)
   - Data parsing
   - Calculations
   - Formatting

6. `FluidPositionsServiceTests` (10 tests)
   - Contract calls
   - Response parsing

7. `TransakServiceTests` (15 tests)
   - URL building
   - Validation

8. `WithdrawViewModelTests` (25 tests)
   - Balance loading
   - Conversions
   - Validation

9. `Web3ClientTests` (20 tests)
   - RPC calls
   - Fallback logic

10. `ERC20ContractTests` (15 tests)
    - Balance fetching
    - ABI encoding

11. `VaultConfigServiceTests` (10 tests)
    - Config fetching
    - Parsing

**Total Coverage:** ~86% of critical financial code

### Test Execution

```bash
# Run all tests
xcodebuild test \
  -scheme "PerFolioTests" \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test \
  -scheme "PerFolioTests" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:PerfolioTests/FluidVaultServiceTests
```

---

## 🚀 Deployment & CI/CD

### TestFlight Upload

**Workflow:** `.github/workflows/testflight.yml`

```yaml
name: Deploy to TestFlight

on:
  push:
    branches: [main]

jobs:
  build_and_upload:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.0'
      
      - name: Build Archive
        run: |
          xcodebuild archive \
            -scheme "Amigo Gold Prod" \
            -archivePath build/App.xcarchive \
            -configuration Release
      
      - name: Export IPA
        run: |
          xcodebuild -exportArchive \
            -archivePath build/App.xcarchive \
            -exportPath build \
            -exportOptionsPlist exportOptions.plist
      
      - name: Upload to TestFlight
        run: |
          xcrun altool --upload-app \
            --type ios \
            --file build/App.ipa \
            --apiKey ${{ secrets.APP_STORE_CONNECT_KEY_ID }} \
            --apiIssuer ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
```

### Required Secrets

```
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_PRIVATE_KEY
APP_STORE_TEAM_ID
```

---

## 📱 Android Implementation Guide

### Overview

This section provides guidance for replicating PerFolio on Android using Kotlin and Jetpack Compose.

### Recommended Stack

**Core:**
- Language: Kotlin 1.9+
- UI: Jetpack Compose
- Architecture: MVVM with Coroutines
- DI: Hilt
- Networking: Retrofit + OkHttp

**Blockchain:**
- Web3j library for Ethereum interaction
- Or custom RPC client (similar to iOS)

**Authentication:**
- Privy Android SDK (if available)
- Or implement custom JWT verification

### Architecture Mapping

| iOS Component | Android Equivalent |
|---|---|
| SwiftUI View | Jetpack Compose Composable |
| ViewModel (@Published) | ViewModel (StateFlow) |
| Combine | Kotlin Flow |
| async/await | Coroutines (suspend functions) |
| Actor | Mutex / synchronized |
| UserDefaults | SharedPreferences / DataStore |

### Key Differences to Consider

1. **Privy SDK:**
   - Check if Privy offers Android SDK
   - If not, implement custom embedded wallet
   - Use Web3j for transaction signing

2. **RPC Calls:**
   - Use Web3j's `eth_call` and `eth_sendTransaction`
   - Implement similar fallback logic

3. **SafariViewController:**
   - Use Custom Tabs for OnMeta/Transak widgets
   - Handle deep link returns

4. **Decimal Handling:**
   - Use BigDecimal for calculations
   - Be careful with precision in wei conversions

5. **Theme:**
   - Use Material 3 with custom gold color scheme
   - Similar component structure

### Sample Code Structure

```
app/
├── ui/
│   ├── theme/
│   │   └── PerFolioTheme.kt
│   ├── screens/
│   │   ├── borrow/
│   │   │   ├── BorrowScreen.kt
│   │   │   └── BorrowViewModel.kt
│   │   ├── loans/
│   │   │   ├── ActiveLoansScreen.kt
│   │   │   └── ActiveLoansViewModel.kt
│   │   └── wallet/
│   │       ├── WalletScreen.kt
│   │       └── WalletViewModel.kt
│   └── components/
│       ├── PerFolioCard.kt
│       └── PerFolioButton.kt
├── data/
│   ├── models/
│   │   ├── BorrowPosition.kt
│   │   └── VaultConfig.kt
│   ├── repositories/
│   │   ├── FluidRepository.kt
│   │   └── Web3Repository.kt
│   └── services/
│       ├── Web3Service.kt
│       ├── FluidVaultService.kt
│       └── ERC20Service.kt
├── domain/
│   ├── usecases/
│   │   ├── ExecuteBorrowUseCase.kt
│   │   └── FetchPositionsUseCase.kt
│   └── calculations/
│       └── BorrowCalculations.kt
└── di/
    └── AppModule.kt
```

### Implementation Phases for Android

**Phase 1:** Setup & Theme (Week 1)
- Create project structure
- Implement theme system
- Build component library
- Create navigation

**Phase 2:** RPC & Contracts (Week 2)
- Web3 client implementation
- ERC-20 contract interactions
- Fluid Protocol integration
- ABI encoding/decoding

**Phase 3:** Borrow Feature (Week 3)
- Borrow screen UI
- ViewModel with calculations
- Transaction flow
- Testing

**Phase 4:** Active Loans (Week 4)
- Loans screen UI
- Position management
- Action handlers
- Testing

**Phase 5:** Wallet Features (Week 5)
- Deposit (OnMeta integration)
- Swap (0x API integration)
- Withdraw (Transak integration)
- Testing

**Phase 6:** Polish & Release (Week 6)
- Bug fixes
- Performance optimization
- Play Store preparation
- Release

---

## 📚 Additional Resources

### Documentation Links

- **Privy Documentation:** https://docs.privy.io/
- **Fluid Protocol Docs:** https://docs.fluid.instadapp.io/
- **0x API Docs:** https://0x.org/docs/api
- **Alchemy Docs:** https://docs.alchemy.com/
- **OnMeta Docs:** (Contact OnMeta for API docs)
- **Transak Docs:** https://docs.transak.com/

### Smart Contract Explorers

- **PAXG:** https://etherscan.io/token/0x45804880De22913dAFE09f4980848ECE6EcbAf78
- **USDC:** https://etherscan.io/token/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
- **Fluid Vault:** https://etherscan.io/address/0x238207734AdBD22037af0437Ef65F13bABbd1917

### Key Contacts

- **Fluid Protocol Support:** support@fluid.instadapp.io
- **Privy Support:** support@privy.io
- **0x Support:** support@0x.org

---

## 🔄 Version History

### v1.0 - November 2024
- ✅ Initial iOS implementation complete
- ✅ All core features implemented
- ✅ 86% test coverage achieved
- ✅ TestFlight deployment configured
- ✅ Gas sponsorship via Privy
- ✅ Comprehensive documentation created

---

## 📝 Notes for Future Updates

1. **Update this document when:**
   - New features are added
   - Smart contract addresses change
   - API endpoints change
   - New third-party services integrated
   - Architecture changes significantly

2. **Android Development:**
   - Use this document as the single source of truth
   - Keep iOS and Android implementations in sync
   - Share common business logic patterns
   - Maintain feature parity

3. **Maintenance:**
   - Review quarterly for accuracy
   - Update with lessons learned
   - Add troubleshooting sections as issues arise
   - Keep contract addresses current

---

**End of Master Project Specification v1.0**

*This document should be used as the primary reference for understanding, maintaining, and replicating the PerFolio application across platforms.*

