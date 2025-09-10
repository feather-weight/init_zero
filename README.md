# HashApp / Wallet Scanner

[![Ethical Use: Watch‑Only](https://img.shields.io/badge/Ethical%20Use-Watch--Only%20By%20Default-brightgreen)](#purpose-ethics--safe-use)
[![Sweeping: Disabled](https://img.shields.io/badge/Sweeping-Disabled%20by%20default-lightgrey)](#purpose-ethics--safe-use)
[![Responsible Disclosure](https://img.shields.io/badge/Security-Responsible%20Disclosure-blue)](SECURITY.md)
[![Code of Conduct](https://img.shields.io/badge/Community-Code%20of%20Conduct-9cf)](CODE_OF_CONDUCT.md)

## Purpose, Ethics & Safe Use

- Why this exists: Generates HD extended keys for recovery research, surfaces only valid hits (addresses with activity), and visualizes progress. Designed for defensive, educational workflows.
- Statistical reality: The probability that a random key maps to a used Bitcoin address is ~10⁻⁴⁰. Treat this as instrumentation, not a money printer.

See Repository Guidelines and SECURITY.md for details on configuration and safe use.

## Hex Generation Utility (backend)

The backend exposes a small helper to generate hex strings with optional randomization and range bounds.

- Route: `POST /utils/hex/generate` (requires auth cookie)
- Body (JSON):
  - `count` (int, default 100, capped by `HEX_QUEUE_MAX`)
  - `length` (int, default 64; even; used if no `min_hex`/`max_hex`)
  - `min_hex` / `max_hex` (strings; inclusive bounds; `0x` allowed)
  - `randomize` (bool, default true)
  - `unique` (bool, default true)
  - `prefix_0x` (bool, default false)
- Response: `{ count, items: string[], truncated }`

Examples:

```json

{
  "count": 10
}
```
```json
{ 
  "min_hex": "0x1000", 
  "max_hex": "0x1fff", 
  "count": 50,
  "randomize": true
}
```
```json
{ 
  "min_hex": "00",
  "max_hex": "ff",
  "count": 16, 
  "randomize": false
}
```

```

Configure the cap via `HEX_QUEUE_MAX` (default 2048) in your environment.

## Derive From Hex (backend)

Convert a hex seed (≤64 chars) into mainnet extended keys and reference addresses.

- Route: `POST /utils/derive/from-hex` (requires auth cookie)
- Body: `{ "hex": "deadbeef" }` (left-padded to 64 hex chars)
- Returns: `{ xprv, xpub, ypub, zpub, btc_address, eth_address }`

Notes:
- Mainnet only: rejects testnet extended keys elsewhere; this endpoint builds mainnet x/y/z extended keys using our own Base58Check encoding.
- BIP32 serialization uses depth=0, parent fingerprint=0, child=0, and a dummy chain code of 32 zero bytes for seeds that are not BIP39 mnemonics.

## Extended Key Handling (Mainnet only)

- Input support: Accepts `xpub`, `ypub`, `zpub`. Testnet prefixes (e.g., `tpub`, `upub`, `vpub`) are rejected.
- Normalization: `ypub`/`zpub` are automatically converted to `xpub` by swapping version bytes (we re‑encode with our own Base58Check). This is recorded under `meta.xpub_normalization` in scan results:
  - `original`, `original_prefix`, and `normalized_xpub`.
- Providers: The normalized `xpub` is then scanned via our Blockchair integration, and (when enabled) Tatum is used to cross‑check candidate addresses. This ensures we do not miss accounts originating from `ypub`/`zpub` inputs.
