## PerFolio Implementation Plan

### Phase 1 – Branding & Foundation
- **Theme System Refresh**  
  - Update shared palette (background, card, accent, typography sizes) to mirror the PerFolio web style (charcoal backgrounds, gold accent `#EAB308`, SF Rounded weights).  
  - Extend `ThemePalette`, `ThemeTypography`, and button/card components with the new gradient, outline, and spacing rules.
- **Landing & Onboarding**  
  - Rebuild splash/landing content with new hero headline/subheading, three feature cards, how-it-works steps, benefits list, and dual CTAs (“Get Started Now”, “Learn More”).  
  - Add section anchors/scroll behavior for “Learn More”; ensure localized strings for all new copy.
- **Privy & Auth Setup**  
  - Configure Privy with dark theme + gold accent, email-first login, wallet-order priority, embedded wallet creation, and post-auth redirect to Dashboard.  
  - Display wallet connection badge + address in the header once authenticated.

### Phase 2 – Navigation Shell & Layout System
- **Liquid Glass Tab Conversion**  
  - Replace the existing tab structure with three tabs: Dashboard (coins icon), Deposit & Buy (arrow.right.left), Withdraw (wallet).  
  - Use SceneStorage for tab persistence, add sticky header (logo + tagline + logout), and gold pill indicators similar to web.  
  - Maintain per-tab scroll state and add tab accessories/bottom actions if required.
- **Layout Utilities & Components**  
  - Define reusable card/grid spacing, skeleton loaders, warning banners, info badges, and toasts consistent with web behavior.  
  - Ensure responsive tweaks for larger devices (two-column or stacked layouts).

### Phase 3 – Dashboard Build-Out
- **Wallet Balance Card**  
  - Connection status badge (Active/Not Connected states), deposit address with copy/toast, PAXG & USDT balances (loading/error states), manual refresh, and action buttons (Deposit PAXG, Buy Gold).
- **Borrow Section**  
  - Collateral amount input with precision + quick percentage chips (25/50/75/100).  
  - Borrow amount auto-calculation (default 75% of max), manual override, warnings for LTV/health thresholds.  
  - Loan preview metrics (gold price, LTV, health factor, liquidation price, available to borrow) with color coding.  
  - “Borrow USDT” transaction flow: Approvals, operate call, success/error toasts, health warnings.
- **Position Management**  
  - Empty state when no positions.  
  - Position cards per NFT with status badges, health bars, collateral/debt metrics, liquidation warnings, and action buttons (Add Collateral, Repay, Withdraw, Borrow More).  
  - Implement modal scaffolding with input validation, transaction flows, and new metrics preview.  
  - Add aggregated stats (Total Collateral, Total Borrowed, Weighted Health, Borrow APY), gold price chart, and transaction history list with Etherscan links.

### Phase 4 – Deposit & Buy Tab
- **On-Ramp Workflow**  
  - Crypto, fiat, payment method selectors with provider routing logic (OnMeta/Transak), min/max validations, and “Get Quote” step.  
  - Quote view: provider badge, amount breakdown, fees, exchange rate, estimated time, disclaimers.  
  - Widget launch (Safari View Controller) with instructions and return handling; post-transaction toasts and balance refresh.
- **Gold Purchase Module**  
  - USD input with live gold price display, PAXG amount preview, USDT balance validation.  
  - Approval + swap transaction orchestration with success/error toasts.  
  - Info banner (“ℹ️ Gold purchases are instant …”).
- **Supporting Content**  
  - “How It Works” card, security badge, reused gold price chart for tablet layout.

### Phase 5 – Withdraw Tab
- **Off-Ramp Workflow**  
  - USDT-only flow with amount inputs, quick buttons (50%/Max), fiat selection, provider routing, validations, “Get Quote” step.  
  - Quote card mirroring on-ramp but reversed (USDT sell).  
  - Widget launch with instructions for bank transfers, post-return messaging, and balance refresh.
- **Withdrawal Info Card**  
  - Processing time, fee, security sections styled like web reference.  
  - Reuse transaction history component for withdraw tab context.

### Phase 6 – Blockchain & Provider Services
- **Blockchain Service Layer**  
  - Implement ERC-20 helpers (balance, allowance, approve), Fluid vault `operate`, resolver reads (positions, vault config), lending resolver (APY).  
  - Manage RPC endpoints, fallback logic, and transaction state monitoring.  
  - Provide Combine/async publishers for balances, positions, price data.
- **External APIs**  
  - OnMeta/Transak quote clients with routing logic; handle min/max constraints, payment method availability, and widget URL construction.  
  - CoinGecko (or mock) price client for PAXG and historical chart; caching per PRD intervals.  
  - Provider config ingestion (fiat currencies, payment methods, routing rules).

### Phase 7 – UX Polish, Analytics & Release Readiness
- **Transaction UX & Alerts**  
  - Finalize toasts, haptics, copy banners for high LTV/low health, copy-to-clipboard notifications, and widget instructions.  
  - Implement skeleton loaders, manual refresh controls, and risk alerts per thresholds.
- **Analytics & Monitoring**  
  - Hook up analytics events (screen views, tab changes, quote requests, borrow actions, errors) and Crashlytics/Sentry logging.  
  - Add instrumentation for success criteria (TVL, positions, conversion metrics).
- **Testing & Deployment Prep**  
  - Expand unit/integration/UI tests (calculations, provider routing, blockchain mocks, on/off-ramp flows).  
  - Validate accessibility (Dynamic Type, VoiceOver), performance (load times), and finalize App Store/TestFlight artifacts matching new branding.
