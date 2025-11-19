# PerFolio (iOS)

Liquid Glass–styled SwiftUI experience for a crypto-backed gold trading product with Privy authentication, modular architecture, and TestFlight automation.

## Requirements

- Xcode 16 (toolchain with Swift 6)
- iOS 17+ simulator/device (Liquid Glass elements shine on iOS 18/26 betas)
- Swift Package Manager (bundled in Xcode)
- App Store Connect API key (for CI/TestFlight uploads)
- Privy credentials:
  - App ID `cmhvskgil00nvky0cb6rjejrs`
  - Client ID `client-WY6SX56F52MtzFqDzgL6jxdNAfpyL3kdY77zMdG4FgS2J`
  - JWKS endpoint `https://auth.privy.io/api/v1/apps/cmhvskgil00nvky0cb6rjejrs/jwks.json`

## Project Structure

- `Application/` – app root + routing (splash → landing → Liquid Glass tabs)
- `Core/` – shared utilities (environment, theme, networking, SwiftData, localization)
- `Features/`
  - `Auth/` – Privy coordinator, token verifier
  - `Landing/`, `Splash/`
  - `Tabs/` – Dashboard, Wallet, Settings, Liquid Glass tab bar, search sidebar
- `Shared/Components/` – reusable UI atoms (buttons, glass cards, etc.)
- `.github/workflows/testflight.yml` – CI pipeline to archive & upload to TestFlight

## Setup

1. Open `Amigo Gold.xcodeproj` in Xcode 16.
2. Ensure the `Amigo Gold Dev` scheme is selected for debugging (uses `Configurations/Dev.xcconfig`).
3. Replace any placeholder API endpoints or add additional locales/themes as needed.
4. Resolve the Privy Swift Package automatically (already referenced in `Package.resolved`).

### Secrets & Config

- Dev/Prod build configs define:
  - `APP_ENVIRONMENT`, `API_BASE_URL`
  - `PRIVY_APP_ID`, `PRIVY_APP_CLIENT_ID`, `PRIVY_JWKS_URL`
  - `PRIVY_APP_SECRET` – used to sign sponsored Privy RPC requests when sending transactions via Privy REST
  - `DEEP_LINK_SCHEME`, `DEFAULT_OAUTH_PROVIDER`
  - `ALCHEMY_API_KEY` (optional) – mirrors the web `VITE_ALCHEMY_API_KEY`; accept either a full HTTPS RPC URL or a bare Alchemy API key that resolves to `https://eth-mainnet.g.alchemy.com/v2/<key>`
  - `ETHEREUM_RPC_FALLBACK` – default public RPC (kept at `https://ethereum.publicnode.com` to stay aligned with wagmi’s fallback transport)
  - `ZEROX_API_KEY` – 0x Swap API key used for USDC→PAXG quotes/transactions in the wallet swap module
- Update these values only via `Configurations/*.xcconfig` so both Info.plist and runtime configs stay in sync.
- Privy access tokens are verified client-side against JWKS before marking a session as authenticated.

### Running

```
xcodebuild \
  -scheme "Amigo Gold Dev" \
  -project "Amigo Gold.xcodeproj" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

Or run directly from Xcode (Play button) after selecting the desired scheme.

### Tests

```
xcodebuild test \
  -scheme "Amigo Gold Dev" \
  -project "Amigo Gold.xcodeproj" \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Coverage:
- `PrivyTokenVerifierTests` – JWKS fetch/validation failure cases.
- `LandingViewModelTests` – ensures Privy prepare/login/verification and alert states behave correctly.

## TestFlight CI

Workflow: `.github/workflows/testflight.yml`

On push to `main`, GitHub Actions:
1. Builds the `Amigo Gold Prod` scheme (Release) with Xcode 16.
2. Exports an `.ipa` and uploads to TestFlight using App Store Connect API credentials.

Set the following repository secrets before pushing:

| Secret | Description |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | 10-char API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer UUID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of the `.p8` file (single-line) |
| `APP_STORE_TEAM_ID` | Apple Developer Team ID (e.g. `495XWEJ924`) |

Optional: adjust `SCHEME`, `PROJECT`, or export options in the workflow if your naming changes.

## Notes

- Liquid Glass effects require iOS 18 beta (a.k.a. iOS 26) for full fidelity, but components degrade gracefully on iOS 17.
- The right-side glass search drawer appears on regular width (iPad / landscape) to offer global search/shortcuts.
- Privy SDK is consumed via SPM (`Privy` binary package); no manual dependency steps needed beyond having the credentials above. 
