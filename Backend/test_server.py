import base64
import http.client
import json
import threading
import unittest
from unittest.mock import patch

from server import Gateway, response_payload, validate_payload


def sample():
    return {"frames": [{"timestamp": 0.1, "jpegBase64": base64.b64encode(b"\xff\xd8\xfftest").decode()}], "context": "2D estimates"}


class ValidationTests(unittest.TestCase):
    def test_valid_payload_and_no_provider_storage(self):
        payload = validate_payload(sample())
        request = response_payload(payload, "test-model")
        self.assertFalse(request["store"])
        self.assertEqual(request["model"], "test-model")
        self.assertIn("0.100", request["input"][0]["content"][1]["text"])

    def test_rejects_invalid_frames(self):
        for payload in [{}, {"frames": []}, {"frames": sample()["frames"] * 15},
                        {"frames": [{"timestamp": -1, "jpegBase64": "x"}]},
                        {"frames": [{"timestamp": float("nan"), "jpegBase64": "x"}]},
                        {"frames": [{"timestamp": True, "jpegBase64": "x"}]},
                        {"frames": [{"timestamp": 1, "jpegBase64": "not-base64"}]}]:
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                validate_payload(payload)

    def test_rejects_unordered_timestamps_and_oversized_context(self):
        payload = sample()
        payload["frames"] += [{**payload["frames"][0], "timestamp": 0}]
        with self.assertRaises(ValueError): validate_payload(payload)
        payload = sample()
        payload["context"] = "x" * 4001
        with self.assertRaises(ValueError): validate_payload(payload)


class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.server = Gateway(("127.0.0.1", 0), "test-provider-key", "test-token", "test-model")
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def post(self, token, payload):
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_port)
        connection.request("POST", "/feedback", json.dumps(payload), {"Authorization": "Bearer " + token, "Content-Type": "application/json"})
        response = connection.getresponse()
        result = response.status, json.load(response)
        connection.close()
        return result

    def test_rejects_unauthorized_without_calling_provider(self):
        with patch("server.request_feedback") as provider:
            self.assertEqual(self.post("wrong-token", sample())[0], 401)
            provider.assert_not_called()

    def test_returns_feedback_and_rate_limits(self):
        with patch("server.request_feedback", return_value="- Test observation") as provider:
            for _ in range(6):
                self.assertEqual(self.post("test-token", sample()), (200, {"feedback": "- Test observation"}))
            self.assertEqual(self.post("test-token", sample())[0], 429)
            self.assertEqual(provider.call_count, 6)

    def test_upstream_failure_does_not_leak_details(self):
        with patch("server.request_feedback", side_effect=ValueError("sensitive upstream data")):
            status, body = self.post("test-token", sample())
            self.assertEqual(status, 502)
            self.assertNotIn("sensitive", json.dumps(body))


if __name__ == "__main__":
    unittest.main()
