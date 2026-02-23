# Cloudflare Tunnel (Local Proxy Exposure)

## Install (Ubuntu/Debian example)

```bash
# Follow Cloudflare docs for the latest package method
# Example binary install path may vary
cloudflared --version
```

## Run tunnel to local proxy

```bash
./server/run.sh
cloudflared tunnel --url http://localhost:${PROXY_PORT:-8080}
```

Use the generated HTTPS URL in the app's `Proxy Server URL` setting.

## Notes

- Cloudflare Tunnel provides HTTPS for app -> proxy communication during local development.
- For VPS deployment, expose the proxy behind HTTPS (reverse proxy/TLS) and keep the same app setting format.
