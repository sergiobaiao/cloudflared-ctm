#!/usr/bin/env bash 
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

set -euo pipefail
export PATH=./:$PATH
#cloudflared tunnel --no-autoupdate --metrics=0.0.0.0:36500 --origincert=/data/cert.pem --config=/tmp/config.json run km276.ferroviatransnordestinamarquise.com

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
clear_screen() {
    printf "\\033[H\\033[22J"
}
#--------------------------------------
# Logging functions
#--------------------------------------
#log() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
log() { echo -e "$*"; }
log_info()  { log ${green}"INFO: $*" ${clear}; }
log_warn()  { log ${yellow}"WARN: $*" ${clear}; }
log_error() { log ${red}"ERROR: $*" >&2 ${clear}; }
setcolor() { echo -e $*; }

#--------------------------------------
# Allowed commands
#--------------------------------------
COMMANDS=(
  prompt_options
  ensure_options
  load_options
  check_options
  check_connectivity
  has_certificate
  init
  delete_tunnel
  has_tunnel
  create_tunnel
  create_config
  create_dns
  set_log_level
  validate_config
  verify_options
  verify_config
  main
)

#--------------------------------------
# Paths & utilities
#--------------------------------------
#DATA_PATH="./config/cloudflare"
DATA_PATH="$(realpath ./config/cloudflare)"
OPTIONS_FILE="$DATA_PATH/options.json"
TUNNEL_JSON="$DATA_PATH/tunnel.json"
CERT_FILE="$DATA_PATH/cert.pem"
CONFIG_JSON="$DATA_PATH/config.json"

#--------------------------------------
# Validate DATA_PATH
#--------------------------------------
if [[ -d "$DATA_PATH" ]]; then
  [[ -w "$DATA_PATH" ]] || { log_error "DATA_PATH '$DATA_PATH' is not writable"; exit 1; }
else
  mkdir -p "$DATA_PATH" 2>/dev/null || { log_error "Cannot create DATA_PATH '$DATA_PATH'"; exit 1; }
fi

#--------------------------------------
# Preconditions
#--------------------------------------
command -v jq >/dev/null 2>&1 || { log_error "jq is required"; exit 1; }
if ! command -v cloudflared >/dev/null 2>&1; then
  log_warn "cloudflared not found. Downloading binary..."
  command -v curl >/dev/null 2>&1 || { log_error "curl is required"; exit 1; }
  arch="$(uname -m)"
  case "$arch" in
    x86_64)   platform="amd64" ;; 
    aarch64)  platform="arm64" ;; 
    arm64)    platform="arm64" ;; 
    *)        platform="$arch" ;; 
  esac
  url="https://github.com/cloudflare/cloudflared/releases/download/2025.4.2/cloudflared-linux-${platform}"
  log_info "Downloading cloudflared from ${url}"
  curl -fsSL -o ./cloudflared "${url}" || { log_error "Failed to download cloudflared"; exit 1; }
  chmod +x ./cloudflared
  export PATH="${PWD}:$PATH"
  log_info "cloudflared installed to ${PWD}/cloudflared"
fi

# Hostname validation regex
HOSTNAME_REGEX='^(([a-z0-9äöüß]|[a-z0-9äöüß][a-z0-9äöüß-]*[a-z0-9äöüß])\.)*([a-z0-9]|[a-z0-9][a-z0-9-]*[a-z0-9])$'

verify_options(){
# Confirm overwrite if file exists
if [[ -f "$OPTIONS_FILE" ]]; then
    setcolor ${red}
	read -rp "options.json already exists at ${OPTIONS_FILE}. Overwrite? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy] ]]; then
		setcolor ${green}
		log_info "Using existing options.json"
		check_options
		setcolor ${clear}
		return 1
    else
		log_warn "Removing existing $OPTIONS_FILE"
		if rm -f "$OPTIONS_FILE"; then
			log_warn "Removed options file $OPTIONS_FILE"
		else
			log_error "Could not remove $OPTIONS_FILE (check permissions)"
			exit 1
		fi
    fi
fi
}

#--------------------------------------
# Interactive options.json creation
#--------------------------------------
prompt_options() {
  log_info "Creating ${OPTIONS_FILE}"
  verify_options
  setcolor ${cyan}
  read -rp "Tunnel token (Give a token from a remotelly created tunnel or leave blank for local tunnel setup): "$'\033[0;94m\n' tunnel_token
  if [[ ! -z "$tunnel_token" ]]; then
	# Token-only mode: write only TUNNEL_TOKEN to .env
	tunnel_name=""
	external_hostname=""
	additional_hosts_array=()
	echo "TUNNEL_TOKEN=$tunnel_token" > .env
  else
	setcolor ${cyan}
	read -rp "Tunnel name [home-assistant]: "$'\033[0;94m\n' tn; tunnel_name=${tn:-home-assistant}
	echo "TUNNEL_NAME=$tunnel_name" > .env
	setcolor ${cyan}
	read -rp "External hostname: "$'\033[0;94m\n' external_hostname
	echo "EXTERNAL_HOSTNAME=$external_hostname" >> .env
	# Additional hosts (multi-value)
	additional_hosts_array=()
	additional=true
	while true; do
	  setcolor ${cyan}
	  read -rp "Add an additional host? (y/N): " add_host
	  [[ "$add_host" =~ ^[Yy] ]] || break
		read -rp "  Hostname: "$'\033[0;94m' ah_hostname
		read -rp "  Service (e.g. http://host:port): "$'\033[0;94m' ah_service
		additional_hosts_array+=( "$(jq -n --arg h "$ah_hostname" --arg s "$ah_service" '{hostname:$h,service:$s}')" )
	 done
  	# Prepare jq arguments
	args=(
		--arg tunnel_token "$tunnel_token"
		--arg tunnel_name "$tunnel_name"
		--arg external_hostname "$external_hostname"
	)

	# Assemble additional_hosts JSON
	if [[ ${#additional_hosts_array[@]} -gt 0 ]]; then
		additional_hosts_json=$(printf '%s\n' "${additional_hosts_array[@]}" | jq -s '.')
	else
		additional_hosts_json='[]'
	fi
	args+=(--argjson additional_hosts "$additional_hosts_json")

	# Construct jq filter
	filter='{}'
	if [[ -n "$tunnel_token" ]]; then 
		filter+=' | .tunnel_token = $tunnel_token'; 
	fi
	if [[ -n "$tunnel_name" ]]; then 
		filter+=' | .tunnel_name = $tunnel_name'; 
	fi
	if [[ -n "$external_hostname" ]]; then 
		filter+=' | .external_hostname = $external_hostname'; 
	fi
	filter+=' | .additional_hosts = $additional_hosts'

	# Generate options.json
	jq -n "${args[@]}" "$filter" > "$OPTIONS_FILE"
	log_info "options.json written"
	setcolor ${clear}
  fi
}
  
  
#--------------------------------------
# Ensure options.json exists and is valid
#--------------------------------------
ensure_options() {
  if [[ ! -f "$OPTIONS_FILE" ]] || ! jq empty "$OPTIONS_FILE" >/dev/null 2>&1; then
    log_warn "options.json missing or invalid, recreating..."
	if rm -f "$OPTIONS_FILE"; then
		log_warn "Removed options file $OPTIONS_FILE"
	else
		log_error "Could not remove $OPTIONS_FILE (check permissions)"
		exit 1
	fi
    prompt_options
  else
	setcolor ${clear}
  fi
}

#--------------------------------------
# Load configuration
#--------------------------------------
load_options() {
  if [ ! -d "$DATA_PATH" ]; then
	log_error "Configuration folder doesn't exists"
  fi
  
  # Read token: prefer TUNNEL_TOKEN from .env if present
  if [[ -f .env ]]; then
    # shellcheck disable=SC1090
    source .env
    tunnel_token="${TUNNEL_TOKEN:-}"
  else
    tunnel_token=$(jq -r '.tunnel_token // ""' "$OPTIONS_FILE")
  fi

  # Read remaining fields from options.json
  tunnel_name=$(jq -r '.tunnel_name // ""' "$OPTIONS_FILE")
  external_hostname=$(jq -r '.external_hostname // ""' "$OPTIONS_FILE")
  mapfile -t additional_hosts_array < <(jq -c '.additional_hosts[]' "$OPTIONS_FILE" 2>/dev/null || echo "")

  # Echo values back
  log_info "Loaded configuration:"
 if [[ -n "$tunnel_token" ]]; then
    log_warn "TUNNEL_TOKEN found in .env, assuming remotelly configured tunnel"
	log_info "  Tunnel token:      $tunnel_token"
	return 1
 fi
  log_info "  Tunnel name:       ${tunnel_name:-<none>}"
  log_info "  External host:     ${external_hostname:-<none>}"
  log_info "  Additional hosts:"
  if [[ ${#additional_hosts_array[@]} -gt 0 ]]; then
    for entry in "${additional_hosts_array[@]}"; do
      hostname=$(jq -r '.hostname' <<<"$entry")
      service=$(jq -r '.service' <<<"$entry")
      log_info "    - $hostname → $service"
    done
  else
    log_info "    <none>"
  fi
}

#--------------------------------------
# Validate configuration
#--------------------------------------
check_options() {
  load_options
  n=$(jq '.additional_hosts|length' "$OPTIONS_FILE")
  if [[ -z "$tunnel_token" && -z "$external_hostname" && $n -eq 0 && -z "$catch_all_service" && "$nginx_proxy_manager" != true ]]; then
    log_error "Incomplete configuration"; exit 1
  fi
  if [[ -n "$external_hostname" && ! "$external_hostname" =~ $HOSTNAME_REGEX ]]; then
    log_error "Invalid external_hostname: $external_hostname"; exit 1
  fi
  log_info "Configuration validated"
}

#--------------------------------------
# Connectivity test
#--------------------------------------
check_connectivity() {
  pass_test=1
  log_info "Testing connectivity to Cloudflare endpoints"
  for ep in region1.v2.argotunnel.com:7844 region2.v2.argotunnel.com:7844 api.cloudflare.com:443; do
    host=${ep%%:*}
    port=${ep##*:}
    # Use direct exit code check
    if ! nc -z -w2 "$host" "$port"> /dev/null 2>&1; then
      log_error "Cannot reach $host:$port"
	  pass_test=0
    else
      log_info "Reachable $host:$port"
    fi
    if [ $pass_test -eq 0 ]; then
        log_warn "Some necessary services may not be reachable from your host."
        log_warn "Please review lines above and check your firewall/router settings."
		exit 1
    fi
  done
}

#--------------------------------------
# Certificate management
#--------------------------------------
has_certificate() {
if [[ -f "$CERT_FILE" ]]; then
    setcolor {$red}
	read -rp "An existing Certificate was found at ${CERT_FILE}. Overwrite? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy] ]]; then
      log_info "Using existing cert.pem"
      return 1
	else
	  log_warn "Removing existing cert.pem"
		if rm -f "$CERT_FILE"; then
			log_warn "Removed certificate file $CERT_FILE"
		else
			log_error "Could not remove $CERT_FILE (check permissions)"		
			exit 1
		fi	  
    fi
	setcolor {$clear}
  fi

}
init() {
  has_certificate
  log_info "Obtaining Cloudflare cert.pem"
  setcolor ${yellow} 
  check_connectivity
  cloudflared tunnel login
  setcolor ${clear}
  if [ -f ~/.cloudflared/cert.pem ]; then
	mv ~/.cloudflared/cert.pem "$CERT_FILE"
	chmod a+r "$CERT_FILE"
    setcolor ${green} 
    log_info "Certificate saved"
	setcolor {$clear}
  else
    setcolor ${red} 
    log_error "Failed to Generate Certificate..."
	setcolor {$clear}
  fi
}

#--------------------------------------
# Tunnel management
#--------------------------------------
has_tunnel() {
  if [[ ! -f "$TUNNEL_JSON" ]]; then
    log_warn "Tunnel credentials missing at $TUNNEL_JSON"; return 1
  fi
  if [[ ! -f "$CERT_FILE" ]]; then
    log_warn "Certificate missing at $CERT_FILE; run 'init' first"; return 1
  fi
  load_options
  tid=$(jq -r '.id' "$TUNNEL_JSON")
  existing=$(cloudflared tunnel --origincert config/cloudflare/cert.pem list --output json --id "$tid" | jq -r '.[].name')
  if [[ "$existing" != "$tunnel_name" ]]; then
    log_error "Tunnel name mismatch: config=$tunnel_name vs existing=$existing"; return 1
  fi
  log_info "Tunnel matches configuration"
}


verify_tunnel(){
if [[ -f "$TUNNEL_JSON" ]]; then
    setcolor ${red}
	read -rp "tunnel.json already exists at ${OPTIONS_FILE}. Overwrite? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy] ]]; then
		setcolor ${green}
		log_info "Using existing tunnels.json"
		check_options
		setcolor ${clear}
		return 1
	else
		log_error "Removing previous tunnel configuration"
		delete_tunnel
		return 0
	fi
fi	
}
# --------------------------------------
# Delete an existing tunnel
# --------------------------------------
delete_tunnel() {
  # Load our config to get the credentials path
  load_options
  if [[ ! -f "$TUNNEL_JSON" ]] || ! jq empty "$TUNNEL_JSON" >/dev/null 2>&1; then
    log_error "tunnels.json missing or invalid, removing..."
  fi	
  # Grab the tunnel ID from the creds file
  tid=$(jq -r '.id // empty' "$TUNNEL_JSON")
  if [[ -z "$tid" ]]; then
    log_error "No tunnel ID found in $TUNNEL_JSON"
    return
  fi

  # Perform Cloudflare deletion
  log_warn "Deleting tunnel $tid"
  if ! cloudflared tunnel --origincert $CERT_FILE delete "$tid"; then
    log_error "Failed to delete tunnel $tid"
    return
  fi

  # Remove the local credentials file
  if rm -f "$TUNNEL_JSON"; then
    log_warn "Removed tunnel file $TUNNEL_JSON"
  else
    log_warn "Could not remove $TUNNEL_JSON (check permissions)"
	return
  fi
}

#--------------------------------------
# Create new tunnel creds
#--------------------------------------
create_tunnel() {
    # Confirm overwrite if file exists
	verify_tunnel
	setcolor ${green}
	log_info "Creating new tunnel configuration"
	tunnel_name=$(jq -r '.tunnel_name // ""' "$OPTIONS_FILE")
	log_info "Tunnel name: " ${tunnel_name}
	setcolor ${green}
	cloudflared tunnel --origincert $CERT_FILE create --output json "${tunnel_name}"  > "$TUNNEL_JSON"
	chmod a+r "$TUNNEL_JSON"
	log_info "Tunnel credentials saved to $TUNNEL_JSON"
	has_tunnel
	setcolor ${clear}
}

#--------------------------------------
# Ingress configuration
#--------------------------------------
verify_config() {
	if [[ -f "$CONFIG_JSON" ]]; then
		setcolor ${red}
		read -rp "config.json already exists at ${CONFIG_JSON}. Overwrite? (y/N): " overwrite
		if [[ ! "$overwrite" =~ ^[Yy] ]]; then
			setcolor ${green}
			log_info "Using existing config.json"
			validate_config
			setcolor ${clear}
			return 1
		else
			if rm -f "$CONFIG_JSON"; then
				log_warn "Removed tunnel file $CONFIG_JSON"
				return
			else
				log_warn "Could not remove $CONFIG_JSON (check permissions)"
				exit 1
			fi
		fi
	else
		log_warn "$CONFIG_JSON not found"
		return
	fi
}
create_config() {
	local ext="${1:-}"
	verify_config
	if [[ -f "$CONFIG_JSON" ]]; then
		load_options
	fi
	setcolor ${cyan}
	external_hostname=$(jq -r '.external_hostname' "$OPTIONS_FILE")
	tid=$(jq -r '.id' "$TUNNEL_JSON")
	# Start building the ingress array
	ingress=()
	# ── Primary Home Assistant entry ─────────────────────────────────────────
	log_info "Default service for $external_hostname. This is docker network gateway ip by default"
	setcolor ${cyan}
	read -rp "Defaults to [http://172.21.0.1:8123]. Press enter if you don't know what you're doing: "$'\033[0;94m\n' svc
	service_url=${svc:-http://172.21.0.1:8123}
	ingress+=( "$(jq -n \
	  --arg h "$external_hostname" \
	  --arg s "$service_url" \
	  '{hostname:$h,
		service:$s,
		originRequest:{noTLSVerify:true}
	  }')" )
	#printf '%s\n' "${ingress[@]}"
	  # ── Additional hosts from options.json ─────────────────────────────────
	  for entry in "${additional_hosts_array[@]}"; do
		h=$(jq -r '.hostname' <<<"$entry")
		s=$(jq -r '.service'  <<<"$entry")
		ingress+=( "$(jq -n \
		  --arg h "$h" \
		  --arg s "$s" \
		  '{hostname:$h,
			service:$s,
			originRequest:{noTLSVerify:true}
		  }')" )
	  done

	  # ── Final “404” fallback ─────────────────────────────────────────────────
	  ingress+=( "$(jq -n \
		  '{service:"http_status:404",
			originRequest:{noTLSVerify:true}
		  }')" )

	  # ── Emit the final config.json (no top-level originRequest) ────────────
	  jq -n \
		--arg tunnel "$tid" \
		--arg creds  "/data/$tid".json \
		--argjson ingress "$(printf '%s\n' "${ingress[@]}" | jq -s '.')" \
		'{tunnel:$tunnel,
		  "credentials-file":$creds,
		  ingress:$ingress
		}' \
		> "$CONFIG_JSON"
	  chmod a+r "$CONFIG_JSON"
	  chmod a+r $DATA_PATH/*
	  setcolor ${green}
	  validate_config
	  setcolor ${clear}

}

validate_config(){
setcolor ${green}
  if cloudflared tunnel --config "${CONFIG_JSON}" ingress validate; then
    log_info "Ingress configuration validated"
  else
    log_error "Ingress configuration failed"	
	if rm -f "$CONFIG_JSON"; then
		log_warn "Removed tunnel file $CONFIG_JSON"
	else
		log_warn "Could not remove $CONFIG_JSON (check permissions)"
		exit 1
	fi
  fi
  setcolor ${clear}
 }



#--------------------------------------
# Create DNS routes
#--------------------------------------
create_dns() {
  load_options; tid=$(jq -r '.TunnelID' "$TUNNEL_JSON")
  [[ -n "$external_hostname" ]] && cloudflared tunnel route dns "$tid" "$external_hostname"
  jq -r '.additional_hosts[].hostname' "$OPTIONS_FILE" | while read -r h; do
    cloudflared tunnel route dns "$tid" "$h"
  done
  log_info "DNS routes ensured"
}

#--------------------------------------
# Log level configuration
#--------------------------------------
set_log_level() { export TUNNEL_LOGLEVEL="$(jq -r '.run_parameters[]?//"info"' "$OPTIONS_FILE" | grep -oP '(?<=--loglevel=).*')"; }

#--------------------------------------
# Complete setup & run
#--------------------------------------
main() {
  ensure_options
  load_options
  set_log_level
  [[ "$TUNNEL_LOGLEVEL" == debug ]] && check_connectivity
  if [[ -n "$tunnel_token" ]]; then
    exec cloudflared tunnel run --token "$tunnel_token"
  fi
  check_options
  has_certificate || init
  has_tunnel     || create_tunnel
  create_config
  create_dns
  exec cloudflared tunnel run --config "$CONFIG_JSON"
  setcolor {$clear}
}

#--------------------------------------
# Usage/help text
#--------------------------------------
usage() {
  cat <<EOF
Usage: $0 <command> [args...]
Available commands:
  ${COMMANDS[*]}
EOF
}

#--------------------------------------
# Command dispatch
#--------------------------------------
dispatch() {
  local cmd="$1"; shift
  for c in "${COMMANDS[@]}"; do
    if [[ "$c" == "$cmd" ]]; then
      "$cmd" "$@"; return
    fi
  done
  log_error "Unknown or unauthorized command: $cmd"
  usage
  exit 1
}

# Entry point
[[ $# -eq 0 ]] && usage && exit

dispatch "$@"