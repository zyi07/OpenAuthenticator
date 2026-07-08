# Tool_2FA — HarmonyOS 2FA Token Manager

## Project Overview

Native HarmonyOS TOTP authenticator app. Single `entry` module, single page (`pages/Index`), stage model.

- **Bundle**: `com.example.tool_2fa`
- **SDK**: target/compatible `6.1.0(23)` (HarmonyOS), model version `6.1.0`
- **Device types**: phone, tablet
- **UI framework**: ArkUI + `@kit.UIDesignKit` (HdsNavigation, HdsTabs)

## Build & Run

```
build_project                 # debug build (default)
build_project --module entry  # build entry HAP only
build_project --build_mode release
```

Always `build_project` before `start_app`. If incremental build fails unexpectedly, clean first (`build_project --clean`).

## Architecture

```
entry/src/main/ets/
├── pages/Index.ets          # ALL UI — @Entry @Component, ~1750 lines
│                             Uses ~35 @Builder methods for page fragments
│                             (Home, Me, AddToken, QR scan, blur overlay, animations)
├── model/TokenRecord.ets    # TokenRecord interface + sanitizeTokenRecord()
├── data/TokenRepository.ets # Persistence via @kit.ArkData preferences
├── utils/Totp.ets           # TOTP generation (HMAC-SHA1..SHA512, Base32)
├── entryability/EntryAbility.ets   # Full-screen immersive window config,
│                             syncs status-bar/nav-indicator heights to AppStorage
└── entrybackupability/EntryBackupAbility.ets
```

### Key design decisions

- **One giant component**: `Index.ets` holds all UI state and builders. No separate components or pages. Page mode switches via `@State pageMode: PageMode` (Home/AddToken).
- **Safe area**: `EntryAbility` sets `setWindowLayoutFullScreen(true)` and transparent system bars, then publishes `tool2fa_statusBarHeight` / `tool2fa_naviIndicatorHeight` to `AppStorage`. UI reads them via `@StorageProp`.
- **Token persistence**: `TokenRepository` uses `@kit.ArkData` preferences (key `'tokens'`, value is JSON string). No database.
- **TOTP crypto**: `Totp.ets` tries `@ohos.security.cryptoFramework` HMAC first; falls back to a pure-JS SHA-1 implementation if the system API fails. Supports SHA1/SHA3/SHA224/SHA256/SHA384/SHA512.

## Code Linter

`code-linter.json5` applies `@performance/recommended` + `@typescript-eslint/recommended` to all `.ets` files, with strict security rules forbidding unsafe AES, 3DES, RSA, DSA, DH, and weak hash/MAC.

## Gotchas

- **backgroundBlurStyle / immersiveMaterialModifier**: These system-level blur APIs do **not** render in the DevEco Previewer. Verify blur/frosted-glass effects on real device or emulator only.
- **BlurStyle is globally available** — no import needed.
- **HdsNavigation scroll-blur**: The `HdsNavigation` component has built-in gradient blur via `ScrollEffectType.GRADIENT_BLUR` + `hdsMaterial`. This replaced the earlier manual `backgroundBlurStyle` + `linearGradient` approach.
- **as type assertions**: ArkTS strict mode prohibits `as` casts. The `getErrorCode` helper uses `error as Record<string, Object>` which passes in the current strict config but is fragile — avoid adding new `as` casts.
- **Map usage**: `parseQrQuery` returns `Map<string, string>`. ArkTS supports `Map` but not dynamic property access on plain objects.

## Permissions (module.json5)

- `ohos.permission.INTERNET` — network access (for future cloud backup)
- `ohos.permission.DLP_GET_HIDE_STATUS` — anti-peep detection

## Testing

Test files exist under `entry/src/test/` and `entry/src/ohosTest/` but are scaffolds (default DevEco templates). DevDependencies: `@ohos/hypium` (1.0.25), `@ohos/hamock` (1.0.0).

## Style Notes

- All layout constants are top-level `const` in `Index.ets` (e.g. `HOME_TITLE_HEIGHT`, `TOKEN_CARD_HEIGHT`).
- Colors are hex string constants (`PAGE_BACKGROUND`, `BRAND_YELLOW`, etc.), not resource refs.
- Brand yellow: `#EBC500`.
- No comments in source files.
