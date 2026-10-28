# Local feedback gateway

A Python 3.11+ development server that keeps the OpenAI API key off the device. It uses the standard library; no Python packages are required.

## Start

Revoke the old embedded credential and create a fresh server-side key. Set environment variables in your shell or secret manager, following [.env.example](.env.example). The server does not automatically read `.env` files.

```sh
export OPENAI_API_KEY='your-new-server-side-key'
export SPRINTAI_BACKEND_TOKEN="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
python3 Backend/server.py
```

In the simulator, open SprintAI → Settings. Use `http://localhost:8080/feedback` and the **backend token** from your shell. Do not enter the OpenAI API key in the app. The default server binds to loopback only.

On a physical phone, use a trusted HTTPS endpoint reachable by the device. Plain HTTP is accepted by the iOS client only for loopback development URLs. Do not disable TLS verification or add broad App Transport Security exemptions.

The model remains `gpt-4o` to preserve the existing integration. `OPENAI_MODEL` can select another compatible Responses model; verify availability and behavior in your account before changing it.

## Contract

`POST /feedback`, `Authorization: Bearer <backend-token>`, `Content-Type: application/json`:

```json
{
  "frames": [{ "timestamp": 0.5, "jpegBase64": "<base64 JPEG bytes>" }],
  "context": "Optional 2D angle summary"
}
```

Success: `{ "feedback": "Markdown coaching observations" }`.

The gateway validates 1–14 ordered frames, timestamps, JPEG headers, individual frame limits (512 KB), context size (4,000 characters), and total body size (10 MB). It allows up to six authorized requests per minute and two concurrent provider calls per process. Requests use the Responses API with `store: false` and a bounded output length. Error responses do not include provider bodies.

## Tests

```sh
python3 -m unittest discover -s Backend -v
```

All upstream calls are mocked. Tests cover validation, authorization, rate limiting, and error redaction. They bind only to an ephemeral localhost port and never use a real provider key.

## Production work

This is a reference development gateway, not a production hosting solution. Before making it Internet-accessible, use a production server/framework, HTTPS, per-user short-lived authentication, distributed quotas, connection limits, observability with redaction, and deployment-specific privacy/retention controls. Do not ship the shared development token inside a distributed app.
