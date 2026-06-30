# Argyros Community

Self-hosted DEX aggregator and routing engine for [Fogo Chain](https://fogo.io).  
Run your own instance, get optimal swap routes across all major Fogo liquidity pools, and optionally earn referral fees on swaps you route.

> **Source code** is kept private. This repo distributes pre-built binaries and Docker images built from the private source on every tagged release.

---

## What it does

Given a token pair and input amount, Argyros finds the optimal swap path across Vortex (CLMM), FluxBeam (CPMM), and Moonit pools — splitting across multiple routes when that yields a better price. It builds a ready-to-sign Solana transaction that the user's wallet can submit directly on-chain.

```
Your app → POST /api/v1/swap → argyros-community → optimal Solana tx
```

---

## Requirements

| Requirement | Where to get it |
|---|---|
| FluxRPC key | [fluxrpc.com](https://fluxrpc.com?ref=ARGYROS) |
| Community license key | [license.argyros.xyz](https://license.argyros.xyz) |
| Linux server (amd64 or arm64) | Any VPS / bare metal |

The binary validates both at startup and refuses to start if either is missing or invalid.

---

## Quickstart (Docker)

```bash
# 1. Copy the example env file
curl -O https://raw.githubusercontent.com/argyros-ag/argyros-community/main/.env.example
cp .env.example .env

# 2. Fill in your credentials
nano .env   # set RPC_URL, YELLOWSTONE_TOKEN, COMMUNITY_LICENSE_KEY

# 3. Run
docker compose up -d

# 4. Verify
curl http://localhost:8080/health
# → {"status":"ok"}
```

---

## Quickstart (binary)

```bash
# Download for your platform
curl -L https://github.com/argyros-ag/argyros-community/releases/latest/download/argyros-community-linux-amd64 \
  -o argyros-community && chmod +x argyros-community

# Configure
cp .env.example .env && nano .env

# Run
./argyros-community
```

---

## Configuration

Copy `.env.example` to `.env` and fill in:

```env
# Required
COMMUNITY_MODE=true
RPC_URL=https://eu.fogo.fluxrpc.com?key=YOUR_FLUX_RPC_KEY
YELLOWSTONE_URL=https://yellowstone.eu.fogo.fluxrpc.com
YELLOWSTONE_TOKEN=YOUR_FLUX_RPC_KEY
COMMUNITY_LICENSE_KEY=argycom_xxxxxxxxxxxxxxxxxxxx
COMMUNITY_LICENSE_API=https://license.argyros.xyz

# Optional — earn referral fees on swaps you route (dApp builders only)
# REFERRER_WALLET=YourBase58WalletAddress

# Optional — restrict inbound traffic to specific CIDRs
# ALLOWED_IPS=10.0.0.0/8,192.168.1.0/24
```

### Full env reference

| Variable | Required | Default | Description |
|---|---|---|---|
| `COMMUNITY_MODE` | yes | — | Must be `true` |
| `CHAIN` | no | `fogo` | Chain selection (`fogo` only for now) |
| `RPC_URL` | yes | — | FluxRPC endpoint with your API key |
| `YELLOWSTONE_URL` | yes | — | Yellowstone gRPC endpoint |
| `YELLOWSTONE_TOKEN` | yes | — | FluxRPC API key (same as in `RPC_URL`) |
| `COMMUNITY_LICENSE_KEY` | yes | — | License key from license.argyros.xyz |
| `COMMUNITY_LICENSE_API` | yes | — | License server URL |
| `LICENSE_CHECK_INTERVAL` | no | `6h` | How often to re-validate the license |
| `REFERRER_WALLET` | no | — | Your wallet address for referral fees |
| `ALLOWED_IPS` | no | — | Comma-separated CIDRs to allowlist |
| `HTTP_PORT` | no | `8080` | HTTP listen port |
| `HTTP_HOST` | no | `0.0.0.0` | HTTP listen host |
| `LUT_AUTHORITY_KEY_FOGO` | no | — | Private key for Address Lookup Table provisioning |

---

## API

### Endpoints

```
GET  /health                   → {"status":"ok"}
GET  /api/v1/quote             → best route + expected output
POST /api/v1/swap              → ready-to-sign Solana transaction
POST /api/v1/instructions      → raw swap instructions
GET  /api/v1/price/:mint       → spot USD price for a single token
GET  /api/v1/price?mints=...   → spot USD prices for up to 100 tokens (batch)
GET  /api/v1/pools/stats       → pool graph statistics
GET  /api/v1/pools/list        → all indexed pools
GET  /api/v1/pools/:address    → single pool
WS   /api/v1/stream            → real-time quote stream (WebSocket)
```

### Quote

```bash
curl "http://localhost:8080/api/v1/quote?\
inputMint=So11111111111111111111111111111111111111112&\
outputMint=EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v&\
amount=1000000000&\
slippageBps=50"
```

### Swap

```bash
curl -X POST http://localhost:8080/api/v1/swap \
  -H "Content-Type: application/json" \
  -d '{
    "quoteResponse": <quote response from above>,
    "userPublicKey": "YourBase58WalletAddress"
  }'
```

### Price API

Get the live spot USD price for any token derived from real-time pool state:

```bash
# Single token
curl http://localhost:8080/api/v1/price/So11111111111111111111111111111111111111112
# → {"mint":"So1...","price":185.42,"slot":12345678,"updatedAt":1719000000}

# Batch (up to 100 mints, comma-separated)
curl "http://localhost:8080/api/v1/price?mints=So1...,EPjF..."
# → {"prices":[{"mint":"So1...","price":185.42,...},{"mint":"EPjF...","price":1.00,...}]}
```

`price` is `0` when no price is available yet (pool not yet seeded or decimals unknown). `updatedAt` is a Unix timestamp in seconds.

### WebSocket stream

Subscribe to real-time quote updates over WebSocket at `ws://localhost:8080/api/v1/stream`.  
The engine re-runs the quote whenever relevant pool state changes on-chain and pushes the result immediately.

**Subscribe:**
```json
{
  "op": "subscribe",
  "pairs": [
    {
      "in":     "So11111111111111111111111111111111111111112",
      "out":    "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
      "amount": "1000000000",
      "exactIn": true
    }
  ]
}
```

**Server acknowledges:**
```json
{"type":"subscribed","count":1}
```

**Server pushes quote updates:**
```json
{
  "type":           "quote",
  "in":             "So111...",
  "out":            "EPjF...",
  "amount":         "1000000000",
  "amountOut":      "185420000",
  "priceImpactBps": 3,
  "hops":           1,
  "slot":           12345678
}
```

**Unsubscribe:**
```json
{"op":"unsubscribe","pairs":[{"in":"So1...","out":"EPjF...","amount":"1000000000","exactIn":true}]}
```

A single connection supports multiple subscribed pairs. Quotes are pushed only when the output amount changes.

---

## Referral fees (optional)

If you are building a dApp or UI that routes swaps for end users, set `REFERRER_WALLET` to your wallet address. The engine will append your ATA to every swap transaction and the on-chain program will automatically split a portion of the protocol fee to you.

Leave `REFERRER_WALLET` unset if you are running the engine for your own bot or internal trades — there is no "referrer" concept in that case.

---

## Nginx reverse proxy

See [`examples/nginx.conf`](examples/nginx.conf) for a production-ready nginx config with HTTPS via Let's Encrypt.

Quick setup on Ubuntu:
```bash
apt install -y nginx certbot python3-certbot-nginx
cp examples/nginx.conf /etc/nginx/sites-available/argyros.conf
# edit server_name in the config
ln -s /etc/nginx/sites-available/argyros.conf /etc/nginx/sites-enabled/
certbot --nginx -d your-domain.com
```

---

## Releases

| Asset | Description |
|---|---|
| `argyros-community-linux-amd64` | Linux x86-64 binary |
| `argyros-community-linux-arm64` | Linux ARM64 binary |
| Docker image | `ghcr.io/argyros-ag/argyros-community:vX.Y.Z` |

---

## License

The Argyros Community binary is provided for self-hosting under the terms of your community license agreement. Source code is not included in this repository.
