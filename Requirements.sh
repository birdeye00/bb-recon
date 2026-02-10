#!/usr/bin/env bash

set -e

apt install subfinder assetfinder sublist3r amass nmap dirsearch nikto golang -y

if ! command -v gowitness >/dev/null 2>&1; then
  go install github.com/sensepost/gowitness@latest
else
  echo "[+] Gowitness already installed"
fi

if ! command -v gau >/dev/null 2>&1; then
  go install github.com/lc/gau/v2/cmd/gau@latest
else
  echo "[+] gau already installed"
fi

if ! command -v gf >/dev/null 2>&1; then
  go install github.com/tomnomnom/gf@latest
else
  echo "[+] gf already installed"
fi

git clone https://github.com/1ndianl33t/Gf-Patterns
mkdir ~/.gf
mv ./Gf-Patterns/*.json ~/.gf

# -------------------- Detect Shell --------------------
if [[ -n "$ZSH_VERSION" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]]; then
  SHELL_RC="$HOME/.bashrc"
#else
#  echo "[!] Unsupported shell. Please use bash or zsh."
#  exit 1
fi

echo "[+] Using shell config: $SHELL_RC"

# -------------------- Install Go --------------------
if ! command -v go >/dev/null 2>&1; then
  echo "[+] Go not found. Installing Go..."

  sudo apt install golang -y
else
  echo "[+] Go already installed"
fi

# -------------------- Setup Go Environment --------------------
export PATH=$PATH:/usr/local/go/bin

GOPATH=$(go env GOPATH)

echo "[+] GOPATH detected: $GOPATH"

# Add Go paths to shell config if not present
if ! grep -q "GOPATH" "$SHELL_RC"; then
  echo "export PATH=\$PATH:/usr/local/go/bin:\$GOPATH/bin" >> "$SHELL_RC"
else
  echo "[+] Go environment already exists in $SHELL_RC"
fi

# Apply changes to current session
export PATH=$PATH:$GOPATH/bin

# -------------------- Install PDTM --------------------
echo "[+] Installing ProjectDiscovery Tool Manager (PDTM)..."

go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest

# -------------------- Verify Installation --------------------
if command -v pdtm >/dev/null 2>&1; then
  echo "[✓] PDTM installed successfully!"
  pdtm --version
else
  echo "[✗] PDTM installation failed"
  exit 1
fi

HTTPX_PATH=$(command -v httpx 2>/dev/null)

if [[ "$HTTPX_PATH" == "/usr/bin/httpx" ]]; then
  echo "[!] System httpx detected at /usr/bin/httpx — removing"
  rm -f /usr/bin/httpx
fi

pdtm -ia

source $SHELL_RC

git clone https://github.com/projectdiscovery/nuclei-templates.git
mkdir ~/nuclei-templates
mv nuclei-templates/* ~/nuclei-templates/
