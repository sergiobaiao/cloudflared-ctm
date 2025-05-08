#!/usr/bin/env bash
################################################################################
#                                                                              #
#                      ██████╗████████╗███╗   ███╗                             #
#                     ██╔════╝╚══██╔══╝████╗ ████║                             #
#                     ██║        ██║   ██╔████╔██║                             #
#                     ██║        ██║   ██║╚██╔╝██║                             #
#                     ╚██████╗   ██║   ██║ ╚═╝ ██║                             #
#                      ╚═════╝   ╚═╝   ╚═╝     ╚═╝                             #
# ██████╗ ██╗   ██╗███╗   ██╗              ███████╗██╗██████╗ ███████╗████████╗#
# ██╔══██╗██║   ██║████╗  ██║              ██╔════╝██║██╔══██╗██╔════╝╚══██╔══╝#
# ██████╔╝██║   ██║██╔██╗ ██║    █████╗    █████╗  ██║██████╔╝███████╗   ██║   #
# ██╔══██╗██║   ██║██║╚██╗██║    ╚════╝    ██╔══╝  ██║██╔══██╗╚════██║   ██║   #
# ██║  ██║╚██████╔╝██║ ╚████║              ██║     ██║██║  ██║███████║   ██║   #
# ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝              ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   #
#                        CTM — Cloudflare Tunnel Manager                       #
#                              Run First Script                                #
#                                                                              #
# Author:    Sérgio Baião                                                      #
# Repo:      https://github.com/sergiobaiao/cloudflared-ctm                    #
# Created:   2025-05-07                                                        #
# License:   MIT                                                               #
#                                                                              #
# ❖ Overview:                                                                  #
#   - This is a helper script for use with cloudflared.sh                      #
#   - This allows for semi-automated creation of a local cloudflare tunnel     #
#   - It was made primarly to Home Assistant Container users, but can          #
#     be used for any purpose whatsoever.                                      #
#                                                                              #
# ❖ Usage:                                                                     #
#   ./run-first.sh                 # start semi-automated tunnel creation      #
################################################################################
CURRENT_PATH="$(realpath ./)"
SCRIPT_PATH="$CURRENT_PATH/cloudflared.sh"

#define colors
red='\033[0;91m'
green='\033[0;92m'
yellow='\033[0;93m'
blue='\033[0;94m'
magenta='\033[0;95m'
cyan='\033[0;96m'
white='\033[0;97m'
# Clear the color after that
clear='\033[0m'
#--------------------------------------
# Logging functions
#--------------------------------------
#log() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
log() { echo -e "$*"; }
log_info()  { log ${green}"INFO: $*" ${clear}; }
log_warn()  { log ${yellow}"WARN: $*" ${clear}; }
log_error() { log ${red}"ERROR: $*" >&2 ${clear}; }
setcolor() { echo -e $*; }

log_info "Let's start by configuring Cloudflared. For this, we need to download a Cloudflare certificate."
log_info "Let's begin...."
setcolor ${green}
$SCRIPT_PATH init
log_info "Now that we have valid Cloudflare credentials, let's configure the tunnel options"
$SCRIPT_PATH prompt_options
log_info "Now that we have a valid options file, let's create the tunnel.json file."
$SCRIPT_PATH create_tunnel
log_info "Last but not least, let's create a config.json file."
$SCRIPT_PATH create_config
log_info "At last, let's test the bitch, shall we?"
setcolor ${blue}
read -rp "Start cloudflared container for testing (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
		setcolor ${green}
		if ! command -v clear >/dev/null 2>&1; then
			clear
		fi
		log_info "Press CTRL+C to finish this test\n"
		docker compose up cloudflared
		log_warn "Finished cloudflared configuration"
		setcolor ${clear}
	else
		log_info "Finished cloudflared configuration"
		setcolor ${clear}
	fi
