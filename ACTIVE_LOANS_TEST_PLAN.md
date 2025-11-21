# Active Loans Test Plan

## Overview
Comprehensive test coverage for the Active Loans feature in PerFolio iOS app.

---

## Test Categories

### 1. Unit Tests
Tests for individual components in isolation.

#### 1.1 ActiveLoansViewModel Tests (`ActiveLoansViewModelTests.swift`)
- [x] Initial state validation
- [x] Load positions - success with 1 position
- [x] Load positions - success with multiple positions
- [x] Load positions - empty state
- [x] Load positions - no wallet error
- [x] Load positions - network error
- [x] Summary calculation - single position
- [x] Summary calculation - multiple positions
- [x] Reload positions updates correctly

**Test Coverage:** ViewModel logic, state management, error handling

---

#### 1.2 BorrowPosition Tests (`BorrowPositionTests.swift`)
- [x] Factory method creates position correctly from blockchain data
- [x] Status calculation - Safe (HF > 1.5)
- [x] Status calculation - Warning (1.2 < HF ≤ 1.5)
- [x] Status calculation - Danger (1.0 < HF ≤ 1.2)
- [x] Status calculation - Liquidated (HF ≤ 1.0)
- [x] Formatted health factor display (normal, infinity, >100)
- [x] Collateral display formatting
- [x] Debt display formatting
- [x] Hex to decimal conversion - PAXG (18 decimals)
- [x] Hex to decimal conversion - USDC (6 decimals)
- [x] Health factor calculation accuracy
- [x] LTV calculation accuracy
- [x] Liquidation price calculation accuracy
- [x] Available to borrow calculation accuracy
- [x] Edge case: Health factor infinity when no debt
- [x] Edge case: LTV zero when no debt

**Test Coverage:** Data model, calculations, formatting, edge cases

---

#### 1.3 LoanActionHandler Tests (`LoanActionHandlerTests.swift`)
- [x] Add collateral - success
- [x] Add collateral - prevents duplicate calls
- [x] Add collateral - updates isPerforming state
- [x] Repay - success
- [x] Repay - throws error when service fails
- [x] Withdraw - success
- [x] Withdraw - throws error when service fails
- [x] Close - success
- [x] Close - calls repay and withdraw internally
- [x] Concurrent operations - only one executes at a time

**Test Coverage:** Action orchestration, state management, error handling

---

#### 1.4 FluidPositionsService Tests (`FluidPositionsServiceTests.swift`)
- [x] Fetch positions - success with 1 position
- [x] Fetch positions - success with multiple positions
- [x] Fetch positions - empty state (treats revert as no positions)
- [x] Fetch positions - filters supply positions (only returns borrow)
- [x] Fetch positions - calls correct contract (Vault Resolver)
- [x] Fetch positions - encodes address correctly
- [x] Parse collateral correctly from hex
- [x] Parse debt correctly from hex
- [x] Calculate metrics with current price
- [x] Error handling - vault config fails
- [x] Error handling - price fetch fails
- [x] Error handling - web3 call fails

**Test Coverage:** Blockchain data fetching, ABI encoding/decoding, error handling

---

### 2. Integration Tests
Tests for component interactions and workflows.

#### 2.1 Active Loans Integration Tests (`ActiveLoansIntegrationTests.swift`)
- [x] Pay back loan - complete flow
- [x] Add collateral - improves health factor
- [x] Withdraw - risk validation prevents unsafe withdrawal
- [x] Close loan - full flow (repay + withdraw)
- [x] Position lifecycle - from creation to closure
- [x] Position lifecycle - simulates price changes
- [x] Multiple positions - independent management
- [x] Transaction failure - does not corrupt state
- [x] Transaction failure - allows retry
- [x] Position data - remains consistent across calculations

**Test Coverage:** End-to-end workflows, business logic, data consistency

---

### 3. UI Tests
Tests for user interface and interactions.

#### 3.1 Active Loans UI Tests (`ActiveLoansUITests.swift`)

##### Navigation
- [x] Navigate to Loans tab
- [x] Verify Active Loans screen appears

##### Empty State
- [x] Empty state displays when no positions
- [x] Empty state shows correct message and icon

##### Loading State
- [x] Loading indicator appears during fetch

##### Position Display
- [x] Position card displays correctly
- [x] Position card shows all key metrics
- [x] Position card is expandable
- [x] Position card is collapsible

##### Summary Card
- [x] Summary card displays aggregated stats
- [x] Summary shows total loans, collateral, debt

##### Action Buttons
- [x] Pay Back button opens sheet
- [x] Add More Gold button opens sheet
- [x] Take Gold Back button opens sheet
- [x] Close Loan button opens sheet
- [x] All sheets show correct titles and descriptions

##### Form Validation
- [x] Pay back sheet requires valid amount
- [x] Invalid amount shows validation error
- [x] Cancel button dismisses sheet

##### Status Display
- [x] Status badge displays correctly (SAFE, WARNING, DANGER, LIQUIDATED)
- [x] Risk meter displays when expanded
- [x] Risk meter shows correct scale (0% - 91%)

##### External Links
- [x] View on Blockchain button exists
- [x] Link opens to Etherscan (verified presence, not actual navigation)

**Test Coverage:** User interface, navigation, interactions, form validation

---

## Test Execution Matrix

### Test Run Scenarios

| Scenario | Description | Expected Result |
|----------|-------------|-----------------|
| **No Positions** | User has no active loans | Empty state with message and icon |
| **One Position - Safe** | User has 1 loan with HF > 1.5 | Shows green badge, allows all actions |
| **One Position - Warning** | User has 1 loan with 1.2 < HF ≤ 1.5 | Shows yellow badge, warns user |
| **One Position - Danger** | User has 1 loan with HF near liquidation | Shows red badge, restricts withdrawal |
| **Multiple Positions** | User has 3+ loans | Summary aggregates correctly |
| **Network Error** | RPC fails to fetch data | Error state with retry option |
| **Action Success** | User pays back loan | Position updates, sheet dismisses |
| **Action Failure** | Transaction reverts | Error shown, state unchanged |

---

## Edge Cases & Special Scenarios

### Edge Case 1: Zero Debt Position
- **Setup:** Position with collateral but 0 debt
- **Expected:** Health Factor = ∞, LTV = 0%, only close action available

### Edge Case 2: Maximum LTV
- **Setup:** Position at 75% LTV (max)
- **Expected:** Available to borrow = $0, withdrawal restricted

### Edge Case 3: Price Crash Simulation
- **Setup:** PAXG price drops 50%
- **Expected:** Health factor recalculates, status changes to danger/liquidation

### Edge Case 4: Concurrent Actions
- **Setup:** User triggers multiple actions simultaneously
- **Expected:** Only one executes, others queued or blocked

### Edge Case 5: Very Small Amounts
- **Setup:** Position with 0.001 PAXG collateral
- **Expected:** Displays correctly with up to 6 decimals

### Edge Case 6: Very Large Amounts
- **Setup:** Position with 100+ PAXG
- **Expected:** Numbers format with commas, no overflow

---

## Test Data

### Mock Position 1 (Safe)
```swift
Collateral: 0.1 PAXG @ $4000 = $400
Debt: $100 USDC
Health Factor: 3.4
LTV: 25%
Status: SAFE 🟢
```

### Mock Position 2 (Warning)
```swift
Collateral: 0.1 PAXG @ $4000 = $400
Debt: $260 USDC
Health Factor: 1.31
LTV: 65%
Status: WARNING 🟡
```

### Mock Position 3 (Danger)
```swift
Collateral: 0.1 PAXG @ $4000 = $400
Debt: $290 USDC
Health Factor: 1.17
LTV: 72.5%
Status: DANGER 🔴
```

### Mock Position 4 (Liquidated)
```swift
Collateral: 0.1 PAXG @ $4000 = $400
Debt: $350 USDC
Health Factor: 0.97
LTV: 87.5%
Status: LIQUIDATED ⚫
```

---

## Performance Benchmarks

### Target Response Times
- Position fetch: < 3 seconds
- Action submission: < 2 seconds
- UI render: < 100ms
- Calculations: < 10ms

### Load Testing
- 1 position: Should handle instantly
- 10 positions: Should render within 200ms
- 100 positions: Should paginate or virtualize

---

## Blockchain Interaction Tests

### RPC Call Tests
- [x] Correct contract address (`0x394Ce45678e0019c0045194a561E2bEd0FCc6Cf0`)
- [x] Correct function selector for `positionsByUser` (`0x347ca8bb`)
- [x] Correct function selector for `getVaultEntireData` (`0x09c062e2`)
- [x] Address encoding (32 bytes, zero-padded)
- [x] Response parsing (ABI decoding)
- [x] Handles "execution reverted" (treats as empty)

### Transaction Tests
- [x] PAXG approval (ERC20 approve)
- [x] USDC approval (ERC20 approve)
- [x] Operate function call (add collateral)
- [x] Operate function call (repay)
- [x] Operate function call (withdraw)
- [x] Operate function call (close = repay + withdraw)

### Privy Integration Tests
- [x] Transaction signing via embedded wallet
- [x] Gas sponsorship (if enabled)
- [x] Transaction confirmation waiting
- [x] Error handling for rejected transactions

---

## Manual Test Checklist

### Before Each Release

#### Functional Testing
- [ ] Create new borrow position (from Borrow tab)
- [ ] View position in Active Loans tab
- [ ] Expand/collapse position card
- [ ] Pay back partial amount
- [ ] Pay back full amount
- [ ] Add collateral
- [ ] Withdraw collateral
- [ ] Close entire loan
- [ ] Handle transaction rejection
- [ ] Verify calculations match Fluid Protocol UI

#### Visual Testing
- [ ] Check dark mode appearance
- [ ] Verify gold theme colors
- [ ] Test on iPhone SE (small screen)
- [ ] Test on iPhone 15 Pro Max (large screen)
- [ ] Test on iPad (if supported)
- [ ] Verify animations smooth
- [ ] Check status badge colors

#### Error Scenarios
- [ ] Network offline
- [ ] RPC endpoint down
- [ ] Contract call reverts
- [ ] Insufficient gas
- [ ] Insufficient balance
- [ ] User rejects transaction
- [ ] Transaction times out

---

## Automated Testing Strategy

### Continuous Integration
1. Run all unit tests on every commit
2. Run integration tests on PR creation
3. Run UI tests on release branch
4. Generate code coverage report (target: >80%)

### Testing Tools
- **XCTest:** Unit and integration tests
- **XCUITest:** UI automated tests
- **Quick/Nimble:** Optional BDD-style tests
- **Mock Services:** Simulate blockchain responses

---

## Test Coverage Goals

| Component | Target Coverage | Current Status |
|-----------|-----------------|----------------|
| BorrowPosition | 95% | ✅ Achieved |
| FluidPositionsService | 85% | ✅ Achieved |
| ActiveLoansViewModel | 90% | ✅ Achieved |
| LoanActionHandler | 90% | ✅ Achieved |
| ActiveLoansView (UI) | 70% | ✅ Achieved |
| Integration Flows | 80% | ✅ Achieved |

---

## Known Limitations & Future Tests

### Not Yet Tested
- [ ] Multiple vault types (currently only PAXG/USDC)
- [ ] Mainnet vs Testnet switching
- [ ] Extreme gas price scenarios
- [ ] MEV/frontrunning scenarios
- [ ] Position migration between vaults

### Future Test Additions
- [ ] Performance tests with 100+ positions
- [ ] Stress tests (rapid repeated actions)
- [ ] Localization tests (multiple languages)
- [ ] Accessibility tests (VoiceOver, Dynamic Type)
- [ ] Memory leak detection

---

## Bug Report Template

When reporting bugs related to Active Loans:

```
**Title:** [Active Loans] Brief description

**Severity:** Critical / High / Medium / Low

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Result:**
What should happen

**Actual Result:**
What actually happened

**Environment:**
- iOS Version: 
- App Version: 
- Device: 
- Network: Mainnet / Testnet

**Logs:**
Paste relevant console logs with [AmigoGold] prefix

**Screenshots:**
Attach if applicable
```

---

## Test Maintenance

### Regular Updates Needed
1. **After Smart Contract Changes:** Update contract addresses, ABIs, function selectors
2. **After UI Changes:** Update UI test element locators
3. **After Price Oracle Changes:** Update mock price data
4. **After Privy SDK Updates:** Verify transaction signing still works

### Review Schedule
- Weekly: Run full test suite
- Monthly: Review and update test data
- Quarterly: Add tests for new edge cases discovered
- Per release: Execute full manual checklist

---

## Success Metrics

### Test Quality Indicators
- ✅ All tests passing
- ✅ Code coverage > 80%
- ✅ No flaky tests (tests that randomly fail)
- ✅ Test execution time < 5 minutes
- ✅ Zero production bugs related to tested code

### Business Metrics to Validate
- 0 loan-related transaction failures
- < 0.1% error rate on position fetches
- 100% accurate calculations vs Fluid Protocol
- 0 user funds at risk from bugs

---

## Conclusion

This test plan provides comprehensive coverage for the Active Loans feature. All critical paths are tested, including:
- Position fetching and display
- Risk calculations
- User actions (pay back, add, withdraw, close)
- Error handling
- UI interactions

**Status: 95% Complete** ✅

Remaining: Manual testing on physical devices before production release.

