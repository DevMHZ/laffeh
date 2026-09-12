import base64
import json
import unittest
from prepare_public_config import public_config


def jwt(role):
    return "header." + base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=") + ".signature"


class PublicConfigTest(unittest.TestCase):
    def test_privileged_and_unknown_keys_never_enter_asset(self):
        result = public_config("AI_ROUTE_API_KEY=secret\nMAPBOX_ACCESS_TOKEN=secret\nOTHER_SECRET=secret\nSUPABASE_ANON_KEY=" + jwt("anon"))
        self.assertNotIn("secret", result)
        self.assertIn("SUPABASE_ANON_KEY=", result)

    def test_service_role_rejected_even_if_misnamed(self):
        with self.assertRaises(ValueError):
            public_config("SUPABASE_ANON_KEY=" + jwt("service_role"))

    def test_url_cannot_smuggle_credentials(self):
        for url in ["https://host.example/?key=secret", "https://user:secret@host.example"]:
            with self.assertRaises(ValueError):
                public_config("MOBILE_ROUTE_BASE_URL=" + url)


if __name__ == "__main__":
    unittest.main()
