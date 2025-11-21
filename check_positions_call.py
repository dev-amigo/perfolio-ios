#!/usr/bin/env python3
"""
Utility script to reproduce the Fluid `positionsByUser(address)` call via raw
`eth_call`. Helpful when debugging the iOS client—just run:

python scripts/check_positions_call.py \
  --rpc-url https://eth-mainnet.g.alchemy.com/v2/<key> \
  --wallet 0xYourWalletAddress
"""

from __future__ import annotations

import argparse
import json
import ssl
import sys
import urllib.error
import urllib.request


POSITIONS_SELECTOR = "0x919ddbf0"  # keccak256("positionsByUser(address)")[:4]
DEFAULT_RESOLVER = "0x394Ce45678e0019c0045194a561E2bEd0FCc6Cf0"


def build_calldata(address: str) -> str:
    """Build the encoded calldata for positionsByUser(address)."""
    clean = address.lower().strip()
    if not clean.startswith("0x"):
        raise ValueError("wallet address must start with 0x")
    clean = clean[2:]
    if len(clean) != 40 or any(c not in "0123456789abcdef" for c in clean):
        raise ValueError("wallet address must be 40 hex chars (after 0x)")
    return POSITIONS_SELECTOR + clean.rjust(64, "0")


def post_json(url: str, payload: dict, insecure: bool = False) -> dict:
    """Execute a JSON-RPC POST request."""
    data = json.dumps(payload).encode("utf-8")
    context = None
    if insecure:
        context = ssl._create_unverified_context()
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60, context=context) as resp:
        body = resp.read().decode("utf-8")
    return json.loads(body)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Call Fluid VaultResolver.positionsByUser(address)"
    )
    parser.add_argument(
        "--rpc-url",
        required=True,
        help="Ethereum JSON-RPC endpoint (Alchemy/Infura/etc.)",
    )
    parser.add_argument(
        "--wallet",
        required=True,
        help="Wallet address to inspect (0x...)",
    )
    parser.add_argument(
        "--resolver",
        default=DEFAULT_RESOLVER,
        help=f"VaultResolver contract address (default: {DEFAULT_RESOLVER})",
    )
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="Skip TLS certificate verification (useful on macOS if certs are missing)",
    )
    args = parser.parse_args()

    try:
        calldata = build_calldata(args.wallet)
    except ValueError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1

    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_call",
        "params": [
            {
                "to": args.resolver,
                "data": calldata,
            },
            "latest",
        ],
    }

    print("→ RPC URL     :", args.rpc_url)
    print("→ Resolver    :", args.resolver)
    print("→ Wallet      :", args.wallet)
    print("→ Calldata    :", calldata)

    try:
        response = post_json(args.rpc_url, payload, insecure=args.insecure)
    except urllib.error.HTTPError as exc:
        print(f"[http error] {exc.code} {exc.reason}", file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"[network error] {exc.reason}", file=sys.stderr)
        return 1

    print("\nRPC response:")
    print(json.dumps(response, indent=2))

    if "error" in response:
        err = response["error"]
        data = err.get("data")
        if isinstance(data, str):
            print(f"\nDecoded error data: {data}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
