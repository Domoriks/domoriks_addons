# Home Assistant App (Add-on) Development Guide

## Overview

Apps (formerly add-ons) extend Home Assistant functionality. They run as Docker containers and can:

- Provide services (MQTT, databases, etc.)
- Expose configuration (Samba, SSH)
- Integrate with Home Assistant APIs

Apps are distributed via container registries (GitHub Container Registry, Docker Hub).

---

## Tutorial: First App

### Step 1: Create Structure

```
hello_world/
  Dockerfile
  config.yaml
  run.sh
```

### Dockerfile

```
FROM ghcr.io/home-assistant/base:latest

COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
```

### config.yaml

```
name: "Hello world"
description: "My first app!"
version: "1.0.0"
slug: "hello_world"
init: false
arch:
  - aarch64
  - amd64
```

### run.sh

```
#!/usr/bin/with-contenv bashio
echo "Hello world!"
```

---

### Step 2: Install

- Place folder in `/addons`
- Go to:
  - Settings → Apps → App Store
- Click "Check for updates"
- Install & start

---

### Step 3: Add Web Server

#### Dockerfile

```
RUN apk add --no-cache python3
WORKDIR /data
```

#### config.yaml

```
ports:
  8000/tcp: 8000
```

#### run.sh

```
python3 -m http.server 8000
```

Access:

```
http://homeassistant.local:8000
```

---

## App Structure

```
addon_name/
  config.yaml
  Dockerfile
  run.sh
  README.md
  translations/
```

---

## Config Basics

Required:

- name
- version
- slug
- description
- arch

Example:

```
name: "App"
version: "1.0"
slug: "app"
arch: [amd64]
```

---

## Options & Schema

```
options:
  name: "world"

schema:
  name: str
```

---

## Communication

### Home Assistant API

```
http://supervisor/core/api/
Authorization: Bearer $SUPERVISOR_TOKEN
```

### Services

```
bashio::services mqtt "host"
```

---

## Local Development

### Build

```
docker build -t local/app .
```

### Run

```
docker run --rm -v /tmp/data:/data local/app
```

---

## Repository Setup

### repository.yaml

```
name: My Repo
url: https://example.com
maintainer: Me
```

---

## Security

Best practices:

- Avoid host network
- Use minimal privileges
- Read-only mounts where possible
- Avoid full_access

---

## Notes

- `/data` = persistent storage
- `options.json` = user config
- Logs via Docker / Supervisor UI
