# Transmission through Private Internet Access

Docker Compose stack that routes Transmission exclusively through a Private
Internet Access (PIA) VPN using Gluetun. PIA's assigned incoming port is kept
synchronized with Transmission automatically.

## Architecture

- **Gluetun** connects to a PIA OpenVPN server and provides the firewall and
  VPN kill switch.
- **Transmission** shares Gluetun's network namespace, so it has no independent
  route that could bypass the VPN.
- **Port forward synchronizer** reads PIA's assigned port from Gluetun and
  updates Transmission through its local RPC API.
- Only Transmission's web interface on TCP port `9091` is published to the
  host. The PIA peer port arrives through the VPN interface and must not be
  published as a Docker host port.

## Prerequisites

- Docker Engine with the Compose plugin
- A PIA subscription
- PIA OpenVPN credentials from the PIA account page
- A Docker network named `frontend`
- A working `/dev/net/tun` device on the host

Create the external network if it does not already exist:

```bash
docker network create frontend
```

## Configuration

Copy the environment template and restrict its permissions:

```bash
cp .env.example .env
chmod 600 .env
```

Edit `.env` and provide both the Transmission web credentials and PIA OpenVPN
credentials:

```dotenv
TRANSMISSION_USER=change-me
TRANSMISSION_PASS=change-me
PIA_USER=p0000000
PIA_PASS=change-me
PIA_REGION=Netherlands
```

PIA's OpenVPN credentials can differ from the credentials used to sign in to
its website. The selected region must support port forwarding; the Compose
configuration additionally restricts Gluetun to port-forward-capable servers.

Before starting the stack, set the persistent host paths in `.env` for your
system:

```dotenv
TRANSMISSION_CONFIG_PATH=/path/to/transmission/config
TRANSMISSION_DATA_PATH=/path/to/downloads
```

Also change `PUID`, `PGID`, and `TZ` if the included values do not match your
host.

## Start and stop

Validate and start the stack:

```bash
docker compose config --quiet
docker compose up -d
```

Open Transmission at `http://HOST-IP:9091`.

Stop the stack with:

```bash
docker compose down
```

## Verification

Check container health:

```bash
docker compose ps
```

The port-forward synchronizer becomes unhealthy if it cannot successfully
confirm PIA's assigned port with Transmission for approximately two minutes.

Confirm that Gluetun obtained a forwarded port and that the synchronizer
applied the same value to Transmission:

```bash
docker compose exec gluetun cat /gluetun/forwarded_port
docker compose logs --tail=20 port-forward
```

Expected synchronizer output resembles:

```text
Transmission peer port updated to 12345
```

Confirm that Transmission and Gluetun have the same public IP address:

```bash
docker compose exec gluetun wget -qO- https://ipinfo.io/ip
docker compose exec transmission wget -qO- https://ipinfo.io/ip
```

## Updating

Review release notes before applying available image updates. After an update,
recreate the complete stack because Transmission and the synchronizer share
Gluetun's network namespace:

```bash
docker compose pull
docker compose up -d
docker compose ps
```

Verify the public IP and forwarded port again after recreation.

## Security and persistent state

- `.env` is ignored and must never be committed.
- `gluetun/` contains runtime state, including the PIA port-forward lease, and
  is ignored.
- `backups/` is ignored because Transmission configuration archives may contain
  private data.
- Transmission's configuration and downloads remain in the bind-mounted host
  directories.
