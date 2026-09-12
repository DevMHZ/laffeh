"""Reject an Android bundle that includes private configuration.

Usage: python3 scripts/verify_public_bundle.py path.aab [legacy-key-file]
The optional private file lets release QA verify removal without printing it.
"""
import sys
from pathlib import Path
from zipfile import ZipFile

from prepare_public_config import public_config, URL_KEYS


def verify(path, legacy_key=b""):
    with ZipFile(path) as bundle:
        public_path = "base/assets/flutter_assets/assets/public.env"
        config = bundle.read(public_path).decode()
        public_config(config)  # also rejects a misnamed Supabase service key
        for line in config.splitlines():
            if line and not line.startswith("#"):
                name = line.partition("=")[0]
                if name not in URL_KEYS | {"SUPABASE_ANON_KEY"}:
                    raise ValueError("Unexpected configuration field in bundle")
        for info in bundle.infolist():
            if Path(info.filename).name == ".env":
                raise ValueError("Private .env asset is still bundled")
            with bundle.open(info) as member:
                tail = b""
                forbidden = [b"AI_ROUTE_API_KEY"] + ([legacy_key] if legacy_key else [])
                keep = max(map(len, forbidden))
                while chunk := member.read(1024 * 1024):
                    data = tail + chunk
                    if any(value in data for value in forbidden):
                        raise ValueError("Legacy privileged routing configuration remains in bundle")
                    tail = data[-keep:]
    print("Bundle verified: allowlisted public config; no private .env or legacy routing key.")


if __name__ == "__main__":
    legacy = Path(sys.argv[2]).read_bytes().strip() if len(sys.argv) > 2 else b""
    verify(sys.argv[1], legacy)
