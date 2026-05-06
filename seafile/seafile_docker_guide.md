# Seafile Server Community Edition (Docker) Installation Guide

## System Requirements
- Minimum:
  - 2 GB RAM
  - 2 CPU cores (> 2 GHz)

## Seafile Docker Overview

### Core Components
- Seafile Server
- MySQL
- Redis
- Caddy

### Optional Components
- SeaDoc Server
- Notification Server
- Metadata Server
- Seafile AI & Face Embedding

## Seafile Docker Structure
[ Client ] -> [ Caddy ] -> [ Seafile Server ] -> (MySQL, Redis, Extensions)

## Architecture

Supports:
- x86
- ARM64

### Support Matrix

| Component | x86 | ARM |
|----------|-----|-----|
| seafile-mc | √ | √ |
| seafile-pro-mc | √ | √ |
| sdoc-server | √ | √ |
| notification-server | √ | √ |
| seafile-md-server | √ | √ |
| seafile-ai | √ | √ |
| thumbnail-server | √ | √ |
| seasearch | √ | √ |
| face-embedding | √ | X |
| index-server | √ | X |

### ARM Notes
- face-embedding: not supported
- index-server: not supported
- use seasearch-nomkl

### Pull Image
docker pull seafileltd/seafile-mc:13.0-latest

## Setup

mkdir /opt/seafile
cd /opt/seafile

wget -O .env https://manual.seafile.com/13.0/repo/docker/ce/env
wget https://manual.seafile.com/13.0/repo/docker/ce/seafile-server.yml
wget https://manual.seafile.com/13.0/repo/docker/seadoc.yml
wget https://manual.seafile.com/13.0/repo/docker/caddy.yml

## Start

docker compose up -d

## Logs

docker compose logs --follow

## Access

http://your-domain-or-ip
