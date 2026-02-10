#!/usr/bin/env bash

# ==========================================================
# Bug Bounty Recon Automation Script v1
# ==========================================================

set -euo pipefail

# ---------------------- COLORS -----------------------------
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"
BOLD="\033[1m"

# ---------------------- GLOBAL STATE -----------------------
STATE_DIR="$HOME/.bb-recon"
TARGETS_FILE="$STATE_DIR/targets.txt"

# ---------------------- CONFIG -----------------------------
WORDLIST="/usr/share/wordlists/dirb/common.txt"
THREADS=50
HTTPX_OPTS="-silent -follow-redirects"
NMAP_OPTS="-T4 -F"
NUCLEI_SEVERITY="info,low,medium,high,critical"

TOOLS=(subfinder assetfinder amass httpx nmap dirsearch gowitness katana gau gf nuclei nikto)

mkdir -p "$STATE_DIR"

# ---------------------- FUNCTIONS --------------------------

print_stage() {
  local msg="$1"
  echo -e "\n${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${MAGENTA}▶ ${msg}${RESET}"
  echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

check_dependencies() {
  for tool in "${TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || {
      echo "[-] Missing dependency: $tool"; exit 1; }
  done
}

init_targets() {
  mkdir -p "$STATE_DIR"
  touch "$TARGETS_FILE"

  if [[ ! -s "$TARGETS_FILE" ]]; then
    read -rp "Enter target domain: " t
    echo "$t" >> "$TARGETS_FILE"
  fi
}

add_target_if_new() {
  local t="$1"
  grep -qx "$t" "$TARGETS_FILE" || echo "$t" >> "$TARGETS_FILE"
}

create_workspace() {
  BASE_DIR="$PWD/recon-$TARGET"
  mkdir -p "$BASE_DIR"/{subdomains,live_hosts,nmap,directories,screenshots,urls,gf,nuclei,nikto,logs}
}

run_subdomains() {
print_stage "[+] Getting all subdomains"

  subfinder -d "$TARGET" -silent > "$BASE_DIR/subdomains/subfinder.txt" &
  assetfinder --subs-only "$TARGET" > "$BASE_DIR/subdomains/assetfinder.txt" &
  sublist3r -d "$TARGET" -o "$BASE_DIR/subdomains/sublister.txt" &
  chaos-client -d "$TARGET" > "$BASE_DIR/subdomains/chaos.txt" &
  amass enum -passive -d "$TARGET" > "$BASE_DIR/subdomains/amass.txt" &
  wait

  cat "$BASE_DIR/subdomains"/*.txt | sort -u > "$BASE_DIR/subdomains/current.txt"
}

detect_new_subdomains() {
print_stage "[+] Checking new subdomains"

  PREV="$BASE_DIR/subdomains/all_subdomains.txt"
  CUR="$BASE_DIR/subdomains/current.txt"
  NEW="$BASE_DIR/subdomains/new_subdomains.txt"

  touch "$PREV"
  comm -13 "$PREV" "$CUR" > "$NEW"

  if [[ ! -s "$NEW" ]]; then
    echo "[-] No new subdomains for $TARGET"
    return 1
  fi

  while read -r s; do echo "[+] New subdomain found: $s"; done < "$NEW"
  cp "$CUR" "$PREV"
}

run_httpx() {
print_stage "[+] Getting live hosts"

  httpx $HTTPX_OPTS -l "$BASE_DIR/subdomains/new_subdomains.txt" \
    -o "$BASE_DIR/live_hosts/httpx_new.txt"
}

run_screenshots() {
print_stage "[+] Taking screenshots"

  echo "[+] Taking screenshots of live hosts"
LIVE_FILE="$BASE_DIR/live_hosts/httpx_new.txt"

if [[ ! -s "$LIVE_FILE" ]]; then
echo "[-] No live hosts found for screenshots"
return
fi

gowitness scan file \
-f "$LIVE_FILE" \
--screenshot-path "$BASE_DIR/screenshots" \
--timeout 10 \
--threads 4 \ \
--log-level error
}

run_nmap() {
print_stage "[+] Running NMAP on every single live host"

  while read -r h; do
    safe=$(echo "$h" | sed 's#https\?://##g' | tr '/' '_')
    nmap $NMAP_OPTS "$safe" -oN "$BASE_DIR/nmap/$safe.txt" &
  done < "$BASE_DIR/live_hosts/httpx_new.txt"
  wait
}

run_dir_enum() {
  print_stage "[+] Doing Directory Bruteforce"

  while read -r host; do
    safe=$(echo "$host" | sed 's#https\\?://##g' | tr '/' '_')

    dirsearch \
      -u "$host" \
      -w "$WORDLIST" \
      -t "$THREADS" \
      --random-agent \
      --format simple \
      --output "$BASE_DIR/directories/dirsearch_$safe.txt" 

  done < "$BASE_DIR/live_hosts/httpx_new.txt"

  wait
}

run_urls() {
print_stage "[+] Extracting URLs"

  katana -list "$BASE_DIR/live_hosts/httpx_new.txt" -silent \
    -o "$BASE_DIR/urls/katana.txt"
  gau --subs "$TARGET" > "$BASE_DIR/urls/gau.txt"
  cat "$BASE_DIR/urls"/*.txt | sort -u > "$BASE_DIR/urls/all_urls.txt"
}

run_gf() {
print_stage "[+] Running GF to get patterns"

  for p in xss sqli lfi ssrf redirect cmdi rce debug_logic idor interestingEXT interestingsubs interestingparams debug img-traversal jsvar ssti; do
    cat "$BASE_DIR/urls/all_urls.txt" | gf "$p" > "$BASE_DIR/gf/$p.txt"
  done
}

run_nuclei() {
print_stage "[+] Running nuclei scan"

nuclei -l "$BASE_DIR/live_hosts/httpx_new.txt" \
    -severity "$NUCLEI_SEVERITY" \
    -templates "$HOME/nuclei-templates" \
    -o "$BASE_DIR/nuclei/results.txt"
}

run_nikto() {
print_stage "[+] Running nikto scan"

  while read -r h; do
    safe=$(echo "$h" | sed 's#https\?://##g' | tr '/' '_')
    nikto -h "$h" -o "$BASE_DIR/nikto/$safe.txt" &
  done < "$BASE_DIR/live_hosts/httpx_new.txt"
  wait
}

# ---------------------- MAIN -------------------------------

check_dependencies
init_targets

while read -r TARGET; do
  create_workspace

  run_subdomains
  detect_new_subdomains || continue

  run_httpx
  run_screenshots
  run_nmap
  run_dir_enum
  run_urls
  run_gf
  run_nuclei
  run_nikto

done < "$TARGETS_FILE"
