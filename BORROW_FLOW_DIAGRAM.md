# Borrow Feature - Visual Flow Diagrams

## 🎯 Complete User Journey

```
┌─────────────────────────────────────────────────────────────────────┐
│                      USER OPENS BORROW TAB                          │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  BorrowViewModel      │
                    │  .onAppear()          │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  loadInitialData()    │
                    └───────────┬───────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
    ┌─────────────────┐  ┌──────────────┐  ┌──────────────┐
    │ FluidVaultService│  │PriceOracle   │  │ ERC20Contract│
    │ .initialize()    │  │              │  │              │
    └────────┬─────────┘  └──────┬───────┘  └──────┬───────┘
             │                   │                  │
             │                   │                  │
    ┌────────┴────────┐  ┌──────┴───────┐  ┌──────┴───────┐
    │ Fetch Vault     │  │ Fetch PAXG   │  │ Fetch PAXG   │
    │ Config:         │  │ Price:       │  │ Balance:     │
    │ • maxLTV: 75%   │  │ $4,183       │  │ 0.5 PAXG     │
    │ • liqThresh:85% │  │              │  │              │
    └─────────────────┘  └──────────────┘  └──────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ viewState = .ready    │
                    │ UI Displayed          │
                    └───────────────────────┘
```

---

## 📝 User Input & Real-Time Calculation

```
┌────────────────────────────────────────────────────────────────────┐
│                    USER ENTERS AMOUNTS                             │
│                                                                    │
│  ┌─────────────────────────┐    ┌─────────────────────────┐     │
│  │ Collateral Input        │    │ Borrow Amount Input     │     │
│  │ "0.1"                   │    │ "100"                   │     │
│  │ (PAXG)                  │    │ (USDC)                  │     │
│  └─────────────────────────┘    └─────────────────────────┘     │
└────────────┬────────────────────────────────┬────────────────────┘
             │                                │
             └────────────────┬───────────────┘
                              ▼
                    ┌─────────────────────┐
                    │ Combine Publishers  │
                    │ .debounce(300ms)    │
                    └──────────┬──────────┘
                               ▼
                    ┌─────────────────────┐
                    │ updateMetrics()     │
                    └──────────┬──────────┘
                               ▼
                    ┌─────────────────────────────┐
                    │     BorrowMetrics           │
                    │                             │
                    │ collateralValueUSD:         │
                    │  0.1 × $4,183 = $418.30     │
                    │                             │
                    │ maxBorrowableUSD:           │
                    │  $418.30 × 0.75 = $313.73   │
                    │                             │
                    │ currentLTV:                 │
                    │  ($100 / $418.30) × 100     │
                    │  = 23.9%                    │
                    │                             │
                    │ healthFactor:               │
                    │  ($418.30 × 0.85) / $100    │
                    │  = 3.56                     │
                    │                             │
                    │ liquidationPrice:           │
                    │  $100 / (0.1 × 0.85)        │
                    │  = $1,176.47                │
                    └──────────┬──────────────────┘
                               ▼
                    ┌─────────────────────┐
                    │ validate()          │
                    └──────────┬──────────┘
                               │
                ┌──────────────┼──────────────┐
                ▼              ▼              ▼
         ┌────────────┐ ┌─────────────┐ ┌──────────────┐
         │Balance OK? │ │Max Borrow?  │ │Health OK?    │
         │✅ 0.1≤0.5  │ │✅ 100≤313.73│ │✅ 3.56≥1.5   │
         └────────────┘ └─────────────┘ └──────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Update UI:          │
                    │ • Risk Metrics ✅   │
                    │ • No Warnings       │
                    │ • Button Enabled    │
                    └─────────────────────┘
```

---

## 🚀 Transaction Execution Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│          USER CLICKS "BORROW USDC" BUTTON                           │
└───────────────────────────────────┬─────────────────────────────────┘
                                    ▼
                        ┌───────────────────────┐
                        │ executeBorrow()       │
                        │ Show Modal            │
                        └───────────┬───────────┘
                                    │
                                    ▼
        ╔═══════════════════════════════════════════════════╗
        ║      STEP 1: CHECKING APPROVAL                    ║
        ╚═══════════════════════════════════════════════════╝
                                    │
                                    ▼
                    ┌───────────────────────────────────┐
                    │ FluidVaultService                 │
                    │ .checkPAXGAllowance()             │
                    │                                   │
                    │ Call: PAXG.allowance(             │
                    │   owner: userAddress,             │
                    │   spender: vaultAddress           │
                    │ )                                 │
                    └────────────────┬──────────────────┘
                                     │
                        ┌────────────┴────────────┐
                        ▼                         ▼
                 ┌──────────────┐        ┌──────────────┐
                 │Allowance ≥   │        │Allowance <   │
                 │collateral    │        │collateral    │
                 │✅ SKIP       │        │❌ NEED       │
                 │              │        │  APPROVAL    │
                 └──────┬───────┘        └──────┬───────┘
                        │                       │
                        │                       ▼
                        │       ╔═══════════════════════════════════╗
                        │       ║  STEP 2: APPROVING PAXG           ║
                        │       ╚═══════════════════════════════════╝
                        │                       │
                        │                       ▼
                        │           ┌───────────────────────────┐
                        │           │ approvePAXG()             │
                        │           │                           │
                        │           │ Build Transaction:        │
                        │           │ to: PAXG Contract         │
                        │           │ data: approve(            │
                        │           │   spender: vault,         │
                        │           │   amount: 0.1 PAXG        │
                        │           │ )                         │
                        │           └────────────┬──────────────┘
                        │                        │
                        │                        ▼
                        │           ┌───────────────────────────┐
                        │           │ sendPrivyTransaction()    │
                        │           └────────────┬──────────────┘
                        │                        │
                        │                        ▼
                        │           ┌───────────────────────────┐
                        │           │ Privy Wallet UI Opens     │
                        │           │ • Shows tx details        │
                        │           │ • User confirms/rejects   │
                        │           │ • Signs with private key  │
                        │           └────────────┬──────────────┘
                        │                        │
                        │                        ▼
                        │           ┌───────────────────────────┐
                        │           │ TX Hash: 0xabc123...      │
                        │           │ waitForTransaction()      │
                        │           │ (15 sec or confirmed)     │
                        │           └────────────┬──────────────┘
                        │                        │
                        └────────────────────────┘
                                     │
                                     ▼
        ╔═══════════════════════════════════════════════════╗
        ║    STEP 3: DEPOSITING & BORROWING                 ║
        ╚═══════════════════════════════════════════════════╝
                                     │
                                     ▼
                    ┌────────────────────────────────────┐
                    │ executeOperate(request)            │
                    │                                    │
                    │ Build Transaction Data:            │
                    │ ┌────────────────────────────────┐ │
                    │ │ Function: operate()            │ │
                    │ │ Selector: 0x690d8320           │ │
                    │ │                                │ │
                    │ │ Params:                        │ │
                    │ │ • nftId: 0 (new position)      │ │
                    │ │ • newCol: +0.1 PAXG (Wei)      │ │
                    │ │ • newDebt: +100 USDC (units)   │ │
                    │ │ • to: userAddress              │ │
                    │ └────────────────────────────────┘ │
                    └──────────────────┬─────────────────┘
                                       │
                                       ▼
                    ┌────────────────────────────────────┐
                    │ sendPrivyTransaction()             │
                    │ to: Fluid Vault                    │
                    │ data: encoded operate() call       │
                    └──────────────────┬─────────────────┘
                                       │
                                       ▼
                    ┌────────────────────────────────────┐
                    │ Privy Wallet UI Opens              │
                    │ • Shows: Deposit 0.1 PAXG          │
                    │ •        Borrow 100 USDC           │
                    │ • User confirms                    │
                    └──────────────────┬─────────────────┘
                                       │
                                       ▼
                    ┌────────────────────────────────────┐
                    │ TX Hash: 0xdef456...               │
                    │ waitForTransaction()               │
                    └──────────────────┬─────────────────┘
                                       │
                                       ▼
                    ┌────────────────────────────────────┐
                    │ extractNFTId(from: txHash)         │
                    │                                    │
                    │ Parse Transfer event:              │
                    │ ERC721.Transfer(                   │
                    │   from: 0x000...,                  │
                    │   to: userAddress,                 │
                    │   tokenId: 8896                    │
                    │ )                                  │
                    └──────────────────┬─────────────────┘
                                       │
                                       ▼
        ╔═══════════════════════════════════════════════════╗
        ║           SUCCESS! 🎉                             ║
        ╚═══════════════════════════════════════════════════╝
                                       │
                                       ▼
                    ┌────────────────────────────────────┐
                    │ transactionState = .success(       │
                    │   positionId: "8896"               │
                    │ )                                  │
                    │                                    │
                    │ UI Shows:                          │
                    │ • Green checkmark                  │
                    │ • "Borrow Successful! 🎉"          │
                    │ • "Position NFT #8896 created"     │
                    │ • "DONE" button                    │
                    └────────────────────────────────────┘
```

---

## 🔄 Data Models Relationships

```
┌──────────────────────────────────────────────────────────────────────┐
│                         USER INPUTS                                  │
├──────────────────────────────────────────────────────────────────────┤
│  collateralAmount: String = "0.1"                                    │
│  borrowAmount: String = "100"                                        │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      BorrowRequest                                   │
├──────────────────────────────────────────────────────────────────────┤
│  collateralAmount: Decimal = 0.1                                     │
│  borrowAmount: Decimal = 100.0                                       │
│  userAddress: String = "0x742d35..."                                 │
│  vaultAddress: String = "0x238207..."                                │
│                                                                       │
│  Methods:                                                            │
│  • collateralInWei() → "0x16345785d8a0000"                           │
│  • borrowInSmallestUnit() → "0x5f5e100"                              │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
        ▼                                         ▼
┌──────────────────────┐              ┌──────────────────────────────┐
│   BorrowMetrics      │              │  FluidVaultService           │
├──────────────────────┤              ├──────────────────────────────┤
│ Input:               │              │  executeBorrow(request)      │
│ • collateralAmount   │              │      ↓                       │
│ • borrowAmount       │              │  1. checkPAXGAllowance()     │
│ • paxgPrice          │              │  2. approvePAXG()            │
│ • vaultConfig        │              │  3. executeOperate()         │
│                      │              │  4. extractNFTId()           │
│ Calculated:          │              │      ↓                       │
│ • collateralValueUSD │              │  Returns: nftId              │
│ • maxBorrowableUSD   │              └──────────────────────────────┘
│ • currentLTV         │                            │
│ • healthFactor       │                            ▼
│ • liquidationPrice   │              ┌──────────────────────────────┐
│                      │              │      BorrowPosition          │
│ Validation:          │              ├──────────────────────────────┤
│ • isHighLTV          │              │ id: "vault-8896"             │
│ • isUnsafeHealth     │              │ nftId: "8896"                │
│ • canBorrow          │              │ owner: "0x742d35..."         │
│                      │              │ vaultAddress: "0x238207..."  │
│ Display:             │              │ collateralAmount: 0.1        │
│ • formattedHF        │              │ borrowAmount: 100.0          │
│ • healthStatus       │              │ collateralValueUSD: 418.30   │
│ • ltvStatus          │              │ debtValueUSD: 100.0          │
└──────────────────────┘              │ healthFactor: 3.56           │
                                      │ currentLTV: 23.9             │
                                      │ liquidationPrice: 1176.47    │
                                      │ status: .safe                │
                                      │ createdAt: Date()            │
                                      └──────────────────────────────┘
```

---

## 🎨 UI State Machine

```
                    ┌─────────────┐
                    │   .loading  │
                    │             │
                    │ • Skeleton  │
                    │   cards     │
                    │ • Shimmer   │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   .error    │    │   .ready    │    │   .empty    │
│             │    │             │    │ (if needed) │
│ • Error     │    │ • Header    │    │             │
│   icon      │    │ • Balance   │    └─────────────┘
│ • Message   │    │ • Inputs    │
│ • Retry btn │    │ • Metrics   │
└─────────────┘    │ • Banners   │
                   │ • Button    │
                   └──────┬──────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │ Valid    │   │ Warning  │   │ Error    │
    │          │   │          │   │          │
    │ • Green  │   │ • Orange │   │ • Red    │
    │ • Enabled│   │ • Enabled│   │ • Disabled│
    └──────────┘   └──────────┘   └──────────┘
          │
          │ User clicks "BORROW USDC"
          ▼
┌──────────────────────────────────────────┐
│    TransactionState                      │
├──────────────────────────────────────────┤
│                                          │
│  .idle                                   │
│    ↓                                     │
│  .checkingApproval                       │
│    • Step 1 active                       │
│    • Spinner                             │
│    ↓                                     │
│  .approvingPAXG                          │
│    • Step 2 active                       │
│    • "Confirm in wallet"                 │
│    ↓                                     │
│  .depositingAndBorrowing                 │
│    • Step 3 active                       │
│    • "Confirm in wallet"                 │
│    ↓                                     │
│  ┌─────────────────┬──────────────────┐ │
│  ▼                 ▼                  │ │
│  .success(id)      .failed(error)    │ │
│  • Green ✓         • Red ✗           │ │
│  • "Done"          • "Try Again"     │ │
│  • Position ID     • Error message   │ │
└──────────────────────────────────────────┘
```

---

## 📊 Risk Calculation Matrix

```
┌──────────────────────────────────────────────────────────────────────┐
│                    RISK ASSESSMENT MATRIX                            │
└──────────────────────────────────────────────────────────────────────┘

COLLATERAL: 0.1 PAXG @ $4,183 = $418.30

┌────────────┬─────────┬──────────┬─────────┬──────────────────┐
│ Borrow USD │   LTV   │ Health F │ Status  │ UI Response      │
├────────────┼─────────┼──────────┼─────────┼──────────────────┤
│   $50      │  12.0%  │   7.12   │ ✅ SAFE │ Green, Enabled   │
│  $100      │  23.9%  │   3.56   │ ✅ SAFE │ Green, Enabled   │
│  $150      │  35.9%  │   2.37   │ ✅ SAFE │ Green, Enabled   │
│  $200      │  47.8%  │   1.78   │ ⚠️ MOD  │ Yellow, Enabled  │
│  $250      │  59.8%  │   1.42   │ ⚠️ HIGH │ Orange, Enabled  │
│  $280      │  67.0%  │   1.27   │ ⚠️ HIGH │ Orange, Enabled  │
│  $300      │  71.7%  │   1.19   │ ⚠️ HIGH │ Orange, Warning  │
│  $313.73   │  75.0%  │   1.13   │ 🚫 MAX  │ Orange, Blocked  │
│  $320      │  76.5%  │   1.11   │ 🚫 OVER │ Red, Blocked     │
│  $350      │  83.7%  │   1.02   │ 🚫 RISK │ Red, Blocked     │
│  $355.66   │  85.0%  │   1.00   │ ⚫ LIQ   │ Red, Blocked     │
└────────────┴─────────┴──────────┴─────────┴──────────────────┘

LIQUIDATION EVENTS:

┌─────────────────┬──────────────┬──────────┬──────────────────┐
│ PAXG Price Drop │ New Coll Val │ Health F │ Result           │
├─────────────────┼──────────────┼──────────┼──────────────────┤
│ $4,183 → $4,000 │    $400      │   3.40   │ ✅ Still Safe    │
│ $4,183 → $3,000 │    $300      │   2.55   │ ✅ Still Safe    │
│ $4,183 → $2,000 │    $200      │   1.70   │ ⚠️ Warning       │
│ $4,183 → $1,500 │    $150      │   1.28   │ ⚠️ High Risk     │
│ $4,183 → $1,200 │    $120      │   1.02   │ 🚫 Near Liq      │
│ $4,183 → $1,176 │  $117.60     │   1.00   │ ⚫ LIQUIDATED    │
└─────────────────┴──────────────┴──────────┴──────────────────┘

When liquidated:
• Liquidator pays $100 debt
• Liquidator receives 0.1 PAXG (now worth $117.60)
• Liquidator earns 3% penalty (~$3.53)
• User loses all collateral
```

---

## 🔗 Smart Contract Call Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                    APPROVAL TRANSACTION                              │
└──────────────────────────────────────────────────────────────────────┘

FROM: User's Wallet (0x742d35...)
TO:   PAXG Token Contract (0x45804880...)

FUNCTION: approve(address spender, uint256 amount)

CALLDATA:
┌────────────────────────────────────────────────────────────────────┐
│ 0x095ea7b3                                              │ Function  │
│ 000000000000000000000000238207734adbd22037af0437ef65... │ Spender   │
│ 0000000000000000000000000000000000000000000000016345... │ Amount    │
└────────────────────────────────────────────────────────────────────┘

RESULT: ✅ Vault approved to spend 0.1 PAXG

════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────────┐
│                    OPERATE TRANSACTION                               │
└──────────────────────────────────────────────────────────────────────┘

FROM: User's Wallet (0x742d35...)
TO:   Fluid Vault (0x238207...)

FUNCTION: operate(uint256 nftId, int256 newCol, int256 newDebt, address to)

CALLDATA:
┌────────────────────────────────────────────────────────────────────┐
│ 0x690d8320                                              │ Function  │
│ 0000000000000000000000000000000000000000000000000000... │ nftId: 0  │
│ 0000000000000000000000000000000000000000000000016345... │ +0.1 PAXG │
│ 0000000000000000000000000000000000000000000000000000... │ +100 USDC │
│ 000000000000000000000000742d35cc6634c0532925a3b844... │ to: user  │
└────────────────────────────────────────────────────────────────────┘

VAULT PROCESSES:
1. Transfer 0.1 PAXG from user to vault
2. Mint position NFT #8896 to user
3. Transfer 100 USDC from vault to user
4. Emit events:
   • Deposit(user, 0.1 PAXG)
   • Borrow(user, 100 USDC)
   • Transfer(0x000..., user, 8896)  // NFT mint

RESULT: ✅ Position created, NFT #8896 minted, USDC transferred
```

---

## 📱 Responsive Calculation System

```
┌──────────────────────────────────────────────────────────────────────┐
│                   REACTIVE DATA FLOW                                 │
└──────────────────────────────────────────────────────────────────────┘

User Types in TextField
        │
        ▼
@Published var collateralAmount: String
        │
        │ (Combine Publisher)
        ▼
Publishers.CombineLatest($collateralAmount, $borrowAmount)
        │
        ▼
.debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        │
        │ Wait 300ms after user stops typing
        ▼
.sink { [weak self] _ in
    self?.updateMetrics()
}
        │
        ▼
┌───────────────────────────────────────────────────────┐
│ updateMetrics()                                       │
│                                                       │
│ 1. Parse Inputs:                                     │
│    guard let collateral = Decimal(string: input) ... │
│                                                       │
│ 2. Create BorrowMetrics:                             │
│    metrics = BorrowMetrics(                          │
│        collateralAmount: collateral,                 │
│        borrowAmount: borrow,                         │
│        paxgPrice: paxgPrice,                         │
│        vaultConfig: vaultConfig                      │
│    )                                                 │
│                                                       │
│ 3. Validate:                                         │
│    validationError = validate()                      │
└───────────────────┬───────────────────────────────────┘
                    ▼
        ┌───────────────────────┐
        │ UI Updates            │
        │ (SwiftUI Observes)    │
        ├───────────────────────┤
        │ • Risk Metrics Card   │
        │ • Warning Banners     │
        │ • Error Messages      │
        │ • Button State        │
        │ • Color Indicators    │
        └───────────────────────┘

PERFORMANCE:
• Debounce prevents excessive calculations
• Only calculates when user pauses typing
• Calculations are lightweight (<1ms)
• UI updates are smooth and instant
```

---

## 🎯 Key Decision Points

```
╔═══════════════════════════════════════════════════════════════════╗
║                 VALIDATION DECISION TREE                          ║
╚═══════════════════════════════════════════════════════════════════╝

                    START: User clicks "BORROW USDC"
                                │
                                ▼
                    ┌───────────────────────┐
                    │ collateral > 0 AND    │
                    │ borrow > 0?           │
                    └───────────┬───────────┘
                                │
                        ┌───────┴───────┐
                        ▼               ▼
                     ❌ NO            ✅ YES
                        │               │
                        │               ▼
                        │   ┌───────────────────────┐
                        │   │ collateral ≤          │
                        │   │ userBalance?          │
                        │   └───────────┬───────────┘
                        │               │
                        │       ┌───────┴───────┐
                        │       ▼               ▼
                        │    ❌ NO            ✅ YES
                        │       │               │
                        │       │               ▼
                        │       │   ┌───────────────────────┐
                        │       │   │ borrow ≤              │
                        │       │   │ maxBorrowable?        │
                        │       │   └───────────┬───────────┘
                        │       │               │
                        │       │       ┌───────┴───────┐
                        │       │       ▼               ▼
                        │       │    ❌ NO            ✅ YES
                        │       │       │               │
                        │       │       │               ▼
                        │       │       │   ┌───────────────────────┐
                        │       │       │   │ healthFactor ≥ 1.5?   │
                        │       │       │   └───────────┬───────────┘
                        │       │       │               │
                        │       │       │       ┌───────┴───────┐
                        │       │       │       ▼               ▼
                        │       │       │    ❌ NO            ✅ YES
                        │       │       │       │               │
                        ▼       ▼       ▼       ▼               ▼
                    ┌───────────────────────────┐    ┌──────────────┐
                    │ SHOW ERROR                │    │ PROCEED      │
                    │ • Disable button          │    │ • Execute    │
                    │ • Display message         │    │   Borrow     │
                    │ • Red banner              │    └──────────────┘
                    └───────────────────────────┘
```

---

## 🔄 Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          PRESENTATION LAYER                         │
├─────────────────────────────────────────────────────────────────────┤
│  BorrowView.swift                                                   │
│  • Header, inputs, metrics, banners, button                         │
│                                                                      │
│  TransactionProgressView.swift                                      │
│  • Modal with 3-step progress                                       │
│                                                                      │
│  APYChartView.swift                                                 │
│  • Historical APY chart (30 days)                                   │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
┌────────────────────────────────┴────────────────────────────────────┐
│                          VIEWMODEL LAYER                            │
├─────────────────────────────────────────────────────────────────────┤
│  BorrowViewModel.swift                                              │
│  • State management                                                 │
│  • Reactive calculations (Combine)                                  │
│  • Input validation                                                 │
│  • Transaction orchestration                                        │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
┌────────────────────────────────┴────────────────────────────────────┐
│                          DATA MODELS                                │
├─────────────────────────────────────────────────────────────────────┤
│  BorrowRequest                 BorrowMetrics                        │
│  • User inputs                 • Calculated risk metrics            │
│  • Address validation          • LTV, HF, liquidation price         │
│  • Wei conversion              • Validation flags                   │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
┌────────────────────────────────┴────────────────────────────────────┐
│                          SERVICE LAYER                              │
├─────────────────────────────────────────────────────────────────────┤
│  FluidVaultService             BorrowAPYService                     │
│  • executeBorrow()             • fetchBorrowAPY()                   │
│  • checkAllowance()            • generateHistoricalAPY()            │
│  • approvePAXG()               • 1-min cache                        │
│  • executeOperate()                                                 │
│  • extractNFTId()              ERC20Contract                        │
│  • Privy signing               • balanceOf()                        │
│                                • allowance()                        │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
┌────────────────────────────────┴────────────────────────────────────┐
│                          CALCULATION ENGINE                         │
├─────────────────────────────────────────────────────────────────────┤
│  BorrowCalculationEngine.swift                                      │
│  • calculateMaxBorrow()                                             │
│  • calculateHealthFactor()                                          │
│  • calculateCurrentLTV()                                            │
│  • calculateLiquidationPrice()                                      │
│  • calculateAvailableToBorrow()                                     │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
┌────────────────────────────────┴────────────────────────────────────┐
│                          BLOCKCHAIN LAYER                           │
├─────────────────────────────────────────────────────────────────────┤
│  Web3Client                    PrivyAuthCoordinator                 │
│  • eth_call                    • Transaction signing                │
│  • eth_sendTransaction         • Gas sponsorship                    │
│  • RPC with fallback           • Embedded wallet provider           │
│                                                                      │
│  Smart Contracts:                                                   │
│  • Fluid PAXG/USDC Vault (0x238207...)                              │
│  • Fluid Vault Resolver (0x394Ce4...)                               │
│  • Fluid Lending Resolver (0x000000...)                             │
│  • PAXG Token (0x45804880...)                                       │
│  • USDC Token (0xA0b86991...)                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

**Created:** November 21, 2025  
**Status:** Complete & Production Ready ✅

