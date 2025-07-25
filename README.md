# Home Assistant Add-on: Komodo Periphery

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]

_Komodo Periphery agent for monitoring Home Assistant OS system metrics._

## About

This add-on runs the Komodo Periphery agent on your Home Assistant OS installation, allowing you to monitor system metrics (CPU, memory, disk usage) and manage Docker containers through a centralized Komodo Core server.

Komodo is a lightweight, Rust-based system for building and deploying software across multiple servers. The Periphery agent connects to your Komodo Core server and reports system health metrics while providing remote management capabilities.

## Installation

1. Navigate in your Home Assistant frontend to **Supervisor** → **Add-on Store**.
2. Add this repository URL: `https://github.com/your-username/komodo-periphery-addon`
3. Find the "Komodo Periphery" add-on and click it.
4. Click on the "INSTALL" button.

## How to use

1. Set the required configuration options (see Configuration section below).
2. Start the add-on.
3. Check the add-on log output to verify successful connection to your Komodo Core server.

## Configuration

Add-on configuration:

```yaml
komodo_address: "https://your-komodo-server.com"
komodo_api_key: "your-api-key"
komodo_api_secret: "your-api-secret"
log_level: "info"
stats_polling_rate: "5-sec"
container_stats_polling_rate: "1-min"
ssl_enabled: true
monitor_homeassistant: true
```

### Option: `komodo_address` (required)

The full URL of your Komodo Core server (e.g., `https://komodo.example.com`).

### Option: `komodo_api_key` (required)

Your Komodo API key for authentication.

### Option: `komodo_api_secret` (required)

Your Komodo API secret for authentication.

### Option: `log_level`

Controls the verbosity of log output. Valid values: `trace`, `debug`, `info`, `warn`, `error`.

### Option: `stats_polling_rate`

How often to poll the system for stats like CPU and memory usage. 
Valid values: `1-sec`, `5-sec`, `10-sec`, `30-sec`, `1-min`, etc.

### Option: `container_stats_polling_rate`

How often to poll for Docker container statistics.
Valid values: `1-sec`, `5-sec`, `10-sec`, `30-sec`, `1-min`, etc.

### Option: `ssl_enabled`

Enable HTTPS for the Periphery API. Self-signed certificates will be generated if not provided.

### Option: `monitor_homeassistant`

Enable monitoring of Home Assistant service status on the host system.

### Option: `allowed_ips` (optional)

List of IP addresses allowed to access the Periphery API. Empty list allows all IPs.

```yaml
allowed_ips:
  - "192.168.1.100"
  - "10.0.0.50"
```

### Option: `passkeys` (optional)

List of passkeys required to access the Periphery API.

```yaml
passkeys:
  - "your-secure-passkey"
```

## Security

This add-on requires several elevated privileges to monitor system metrics and manage Docker containers:

- **Docker API access**: Required to monitor and manage containers
- **Host network monitoring**: Required to gather system statistics
- **SYS_ADMIN capability**: Required for certain system monitoring operations

The add-on runs as a non-root user (`komodo`) for security, but needs Docker group access for container management.

**Important Security Notes:**
- Use strong, unique API keys and secrets
- Consider using IP allowlists in production environments
- Enable SSL/TLS for encrypted communication
- Regularly update the add-on to receive security patches

## Support

Got questions?

- [Open an issue][issue] for the add-on
- [Komodo Documentation][komodo-docs]
- [Home Assistant Community Forum][forum]

## Authors & Contributors

The original setup of this repository is by [Your Name].

## License

MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[issue]: https://github.com/your-username/komodo-periphery-addon/issues
[komodo-docs]: https://komo.do/docs
[forum]: https://community.home-assistant.io