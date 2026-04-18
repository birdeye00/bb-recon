# BB-Recon

A modular and intelligent Bash-based recon framework for automating common bug bounty workflows with support for incremental scanning, dependency-aware execution, and flexible scope control.

## Features

- Automated recon pipeline (subdomains → live hosts → scanning)
- Incremental scanning (avoids duplicate work)
- Dependency-aware execution (auto-runs required steps)
- Scope control (single domain or include subdomains)
- Interactive menu for selective operations
- Cron-compatible (fully automated runs)
- Organized output structure per target

## Requirements
- subfinder
- assetfinder
- amass
- chaos-client
- sublist3r
- httpx
- nmap
- dirsearch
- gowitness
- katana
- gau
- gf
- nuclei


## Installation

1. Clone the repository:

'''
git clone https://github.com/birdeye00/bb-recon.git
cd bb-recon
'''


2. Run the requirements script:

'''
chmod +x requirements.sh
./requirements.sh
'''


## Usage

Run the main script:

'''
chmod +x bb-recon.sh
./bb-recon.sh
'''


## Workflow

### Step 1 — Enter Target

You will be prompted:

"Enter target domain:"


### Step 2 — Select Operation

1) Subdomain Enumeration (-d)
2) Live Hosts (httpx) (-l)
3) Screenshots (-s)
4) Nmap Scan (-n)
5) Directory Bruteforce (-b)
6) URL Extraction (-u)
7) GF Patterns (-p)
8) Nuclei Scan (-v)
9) Run ALL (default)


### Step 3 — Scope Selection

"Include subdomains in scope? (y/n):"

- `y` → Full recon (includes subdomains)
- `n` → Only the main domain


## Execution Behavior

### Dependency Handling

The tool automatically runs required steps:

| Selected Step | Automatically Runs        |
| ------------- | ------------------------- |
| httpx         | subdomains                |
| urls          | httpx → subdomains        |
| gf            | urls → httpx → subdomains |
| nuclei        | httpx → subdomains        |


### Result Reuse

If results already exist:

'''
[!] subdomains already completed.
Use existing result? (y/n):
'''

- `y` → skip step
- `n` → rerun step


## Scope Modes

### 1. Subdomain Mode (`y`)

Full pipeline:

"subdomains → httpx → scanning"

### 2. Single Domain Mode (`n`)

No subdomain enumeration:

"target → httpx → scanning"

## Cron Automation

To run daily:


"crontab -e"

Add:

"0 9 * * * /full/path/bb-recon.sh >> /full/path/bb-recon.log 2>&1"


### Behavior in Cron:

- No prompts
- Uses saved targets
- Runs full pipeline
- Skips existing results


## Target Management

Targets are stored in:


"~/.bb-recon/targets.txt"

- Manual run → asks for target
- Cron run → uses stored targets


## NOTE

You'd need "PDCP_API_KEY" to run chaos-client and you can freely get the key from projectdiscovery website and then add this in shell config file (.zshrc or .bashrc): 

"export PDCP_API_KEY="YOUR PDCP_API_KEY""


## Disclaimer

Use only on targets you are authorized to test.
