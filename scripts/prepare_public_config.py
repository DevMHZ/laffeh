"""Build the allowlisted public Flutter asset; never bundle the source .env.

Run before flutter run/build. Only public endpoints and a Supabase anon or
publishable key are accepted. Privileged routing and Mapbox keys are omitted.
"""
import base64
import json
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
URL_KEYS = {
    "MOBILE_ROUTE_BASE_URL", "MAP_STYLE_URL", "NOMINATIM_BASE_URL",
    "PHOTON_BASE_URL", "OVERPASS_BASE_URL", "SUPABASE_URL",
}


def public_config(source):
    values = {}
    for line in source.splitlines():
        name, sep, value = line.strip().partition("=")
        if sep and name in URL_KEYS | {"SUPABASE_ANON_KEY"}:
            value = value.strip().strip('"\'')
            if not value:
                continue
            if name in URL_KEYS:
                url = urlsplit(value)
                if url.scheme not in {"https", "http"} or not url.hostname or url.username or url.password or url.query or url.fragment:
                    raise ValueError(f"{name} must be a public URL without credentials or query parameters")
            elif not value.startswith("sb_publishable_"):
                try:
                    payload = value.split(".")[1]
                    claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
                    if claims.get("role") != "anon":
                        raise ValueError("not an anon key")
                except (ValueError, IndexError, TypeError):
                    raise ValueError("SUPABASE_ANON_KEY must be an anon or publishable key") from None
            values[name] = value
    return "# Generated public client configuration. Safe to distribute.\n" + "".join(
        f"{name}={value}\n" for name, value in sorted(values.items())
    )


if __name__ == "__main__":
    source = ROOT / ".env"
    output = ROOT / "assets/public.env"
    output.write_text(public_config(source.read_text() if source.exists() else ""))
    print("Generated assets/public.env using the public configuration allowlist.")
