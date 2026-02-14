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

## Usage
chmod +x requirements.sh

./requirements.sh

chmod +x bb-recon.sh

./bb-recon.sh

## If you want to run this tool automatically everyday, add this to the cron task. (Replace the fullpath of the file)
0 9 * * * /full/path/bb-recon.sh >> /full/path/bb-recon.log 2>&1

keep in mind that you'd need "PDCP_API_KEY" to run chaos-client and you can freely get the key from projectdiscovery website and then add this in shell config file (.zshrc or .bashrc): 

export PDCP_API_KEY="YOUR PDCP_API_KEY"
