# CTM — Cloudflare Tunnel Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)  [![GitHub Release](https://img.shields.io/github/v/release/sergiobaiao/cloudflared-ctm)](https://github.com/sergiobaiao/cloudflared-ctm/releases)

```bash
################################################################################
#                                                                              #
#                      ██████╗████████╗███╗   ███╗                             #
#                     ██╔════╝╚══██╔══╝████╗ ████║                             #
#                     ██║        ██║   ██╔████╔██║                             #
#                     ██║        ██║   ██║╚██╔╝██║                             #
#                     ╚██████╗   ██║   ██║ ╚═╝ ██║                             #
#                      ╚═════╝   ╚═╝   ╚═╝     ╚═╝                             #
#                        CTM — Cloudflare Tunnel Manager                       #
#                                                                              #
# Author:    Sérgio Baião                                                      #
# Repo:      https://github.com/sergiobaiao/cloudflared-ctm                    #
# Created:   2025-05-07                                                        #
# License:   MIT                                                               #
#                                                                              #
# ❖ Overview:                                                                  #
#   - Login, create, delete & route DNS for Cloudflare tunnels                 #
#   - Builds ingress config.json with fallback, hosts array and noTLS verify   #
#   - Supports both interactive prompts and .env/token modes                   #
#                                                                              #
# ❖ Usage:                                                                     #
#   ./cloudflared.sh init                # authenticate & save cert            #
#   ./cloudflared.sh prompt_options      # create options file                 #
#   ./cloudflared.sh create_tunnel       # create tunnel credentials JSON      #
#   ./cloudflared.sh create_config       # generate ingress config.json        #
#   ./cloudflared.sh delete_tunnel       # remove tunnel & creds JSON          #
################################################################################
```

## Features

* Manage Cloudflare tunnels locally: login, create, delete, DNS routing
* Generate ingress `config.json` with host-based routing and fallback
* Support interactive prompts and `.env`/token modes
* Validate connectivity and JSON structures with `jq`
* Colorized output and detailed logging

## Prerequisites

* [cloudflared CLI](https://github.com/cloudflare/cloudflared)
* `jq` (JSON processor)
* Bash 4+

## Installation

```bash
git clone https://github.com/sergiobaiao/cloudflared-ctm.git
cd cloudflared-ctm
chmod +x cloudflared.sh
```

## Usage

```bash
If you want to generate a tunnel by following a step-by-step procedure, follow this:

./cloudflared.sh init             # Authenticate with Cloudflare and save cert
./cloudflared.sh prompt_options   # Create options file                 
./cloudflared.sh create_tunnel    # Create tunnel credentials JSON
./cloudflared.sh create_config    # Generate ingress config.json
docker compose up -d cloudflared  # Start cloudflared container with the newly created tunnel

If you want a more automated version, follow this:
./run-first.sh                    # Initiate an interactive script for creating the tunnel
                                  # this will also allow you to test the tunnel at the end.
docker compose up -d cloudflared  # Start cloudflared container with the newly created tunnel
```
## Contributing

Contributions are welcome! Please open issues and pull requests.

## Copyright
 Based on the work of [Tobias Brenner](https://github.com/brenner-tobias/addon-cloudflared/)
© Sérgio Baião
