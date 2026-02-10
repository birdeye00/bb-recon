# BB-Recon

A powerful, incremental bug bounty reconnaissance automation tool written in Bash.

## Features
- Daily incremental subdomain enumeration
- Live host detection
- Screenshotting
- Port scanning
- Directory Enumeration
- URL discovery
- Pattern extraction
- Vulnerability scanning
- Multi-target support
- Cron-ready automation

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
- nikto

## Usage
chmod +x bb-recon.sh
./bb-recon.sh

## If you want to run this tool automatically everyday, add this to the cron task. (Replace the fullpath of the file)
0 9 * * * /full/path/bb-recon.sh >> /full/path/bb-recon.log 2>&1

