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

TOOLS=(subfinder assetfinder chaos-client sublist3r amass httpx nmap dirsearch gowitness katana gau gf nuclei)

mkdir -p "$STATE_DIR"

# ---------------------- DECLARATION -----------------------------

declare -A DEPENDENCIES

DEPENDENCIES=(
  [subdomains]=""
  [httpx]="subdomains"
  [screenshots]="httpx"
  [nmap]="httpx"
  [dir]="httpx"
  [urls]="httpx"
  [gf]="urls"
  [nuclei]="httpx"
)

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

  if [[ -t 0 ]]; then
    read -rp "Enter target domain: " t

    if [[ -z "$t" ]]; then
      echo "[-] No target provided"
      exit 1
    fi

    grep -qx "$t" "$TARGETS_FILE" || echo "$t" >> "$TARGETS_FILE"

    TARGETS_TO_RUN=("$t")

  else
    if [[ ! -s "$TARGETS_FILE" ]]; then
      echo "[-] No targets found for cron execution"
      exit 1
    fi

    mapfile -t TARGETS_TO_RUN < "$TARGETS_FILE"
  fi
}


add_target_if_new() {
  local t="$1"
  grep -qx "$t" "$TARGETS_FILE" || echo "$t" >> "$TARGETS_FILE"
}

create_workspace() {
  BASE_DIR="$PWD/$TARGET"
  mkdir -p "$BASE_DIR"/{subdomains,live_hosts,nmap,directories,screenshots,urls,gf,nuclei,logs}
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

  if [[ "$SCOPE_MODE" == "single" ]]; then
    echo "$TARGET" > "$BASE_DIR/live_hosts/single_target.txt"

    INPUT_FILE="$BASE_DIR/live_hosts/single_target.txt"

  else
    INPUT_FILE="$BASE_DIR/subdomains/new_subdomains.txt"

    # 🔥 Safety fallback
    if [[ ! -s "$INPUT_FILE" ]]; then
      echo "[!] No new_subdomains.txt found, using current.txt"

      INPUT_FILE="$BASE_DIR/subdomains/current.txt"
    fi
  fi

  httpx $HTTPX_OPTS -l "$INPUT_FILE" \
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

  if [[ "$SCOPE_MODE" == "single" ]]; then
    gau "$TARGET" > "$BASE_DIR/urls/gau.txt"
  else
    gau --subs "$TARGET" > "$BASE_DIR/urls/gau.txt"
  fi

  cat "$BASE_DIR/urls"/*.txt | sort -u > "$BASE_DIR/urls/all_urls.txt"
}

run_gf() {
print_stage "[+] Running GF to get patterns"

  for p in xss sqli lfi ssrf redirect cmdi rce debug_logic idor interestingEXT interestingsubs interestingparams debug img-traversal ssti; do
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

show_menu() {
  echo -e "\nSelect operation:"
  echo "1) Subdomain Enumeration (-d)"
  echo "2) Live Hosts (httpx) (-l)"
  echo "3) Screenshots (-s)"
  echo "4) Nmap Scan (-n)"
  echo "5) Directory Bruteforce (-b)"
  echo "6) URL Extraction (-u)"
  echo "7) GF Patterns (-p)"
  echo "8) Nuclei Scan (-v)"
  echo "9) Run ALL (default)"
  echo ""
  read -rp "Enter choice: " choice
}

map_choice() {
  case "$choice" in
    1|-d) SELECTED_STEP="subdomains" ;;
    2|-l) SELECTED_STEP="httpx" ;;
    3|-s) SELECTED_STEP="screenshots" ;;
    4|-n) SELECTED_STEP="nmap" ;;
    5|-b) SELECTED_STEP="dir" ;;
    6|-u) SELECTED_STEP="urls" ;;
    7|-p) SELECTED_STEP="gf" ;;
    8|-v) SELECTED_STEP="nuclei" ;;
    9|"") SELECTED_STEP="all" ;;
    *) echo "Invalid choice"; exit 1 ;;
  esac
}

check_and_run() {
  local step="$1"

  # 🚫 Skip subdomain step in single mode
  if [[ "$SCOPE_MODE" == "single" && "$step" == "subdomains" ]]; then
    return
  fi

  local dep="${DEPENDENCIES[$step]}"

  # 🔁 Handle dependency
  if [[ -n "$dep" ]]; then
    check_and_run "$dep"
  fi

  local result="${RESULT_FILES[$step]}"

  if [[ -e "$result" && -s "$result" ]]; then
    echo "[!] $step already completed."

    if [[ -t 0 ]]; then
      read -rp "Use existing result? (y/n): " ans
      [[ "$ans" == "y" ]] && return
    else
      return
    fi
  fi

  echo "[+] Running $step..."

  case "$step" in
    subdomains)
  run_subdomains
  detect_new_subdomains || {
    echo "[-] No new subdomains found, using current list"

    cp "$BASE_DIR/subdomains/current.txt" \
       "$BASE_DIR/subdomains/new_subdomains.txt"
  }
;;
    httpx) run_httpx ;;
    screenshots) run_screenshots ;;
    nmap) run_nmap ;;
    dir) run_dir_enum ;;
    urls) run_urls ;;
    gf) run_gf ;;
    nuclei) run_nuclei ;;
  esac
}

ask_scope() {
  if [[ -t 0 ]]; then
    read -rp "Include subdomains in scope? (y/n): " scope_choice

    if [[ "$scope_choice" == "y" ]]; then
      SCOPE_MODE="subdomains"
    else
      SCOPE_MODE="single"
    fi
  else
    SCOPE_MODE="subdomains"  # cron default
  fi
}

# ---------------------- MAIN -------------------------------

check_dependencies
init_targets

for TARGET in "${TARGETS_TO_RUN[@]}"; do

  create_workspace

  # ✅ Define RESULT FILES HERE (because BASE_DIR exists now)
  declare -A RESULT_FILES=(
    [subdomains]="$BASE_DIR/subdomains/all_subdomains.txt"
    [httpx]="$BASE_DIR/live_hosts/httpx_new.txt"
    [screenshots]="$BASE_DIR/screenshots"
    [nmap]="$BASE_DIR/nmap"
    [dir]="$BASE_DIR/directories"
    [urls]="$BASE_DIR/urls/all_urls.txt"
    [gf]="$BASE_DIR/gf"
    [nuclei]="$BASE_DIR/nuclei/results.txt"
  )

  if [[ -t 0 ]]; then
    show_menu
    ask_scope
  else
    choice=9
    SCOPE_MODE="subdomains"
  fi

  # ✅ Map user choice
  map_choice

  # ✅ EXECUTION LOGIC (THIS IS STEP 5)
  if [[ "$SELECTED_STEP" == "all" ]]; then
    for step in subdomains httpx screenshots nmap dir urls gf nuclei; do
      check_and_run "$step"
    done
  else
    check_and_run "$SELECTED_STEP"
  fi

done


status=$(echo "$?")

if [ $status == '0' ]; then
  echo "Successfully Completed"
else
  echo "Some error occured, please try again."
fi
