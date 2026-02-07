#!/usr/bin/env bash

set -euo pipefail

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Update NixOS configuration from the cluster config repository"
    echo ""
    echo "Options:"
    echo "  -h, --hostname HOSTNAME    Set the hostname for the NixOS rebuild (default: current hostname)"
    echo "  --help                     Show this help message and exit"
    echo ""
    echo "Examples:"
    echo "  $0                         # Use current hostname"
    echo "  $0 -h server01            # Use 'server01' as hostname"
    echo "  $0 --hostname k3s-master  # Use 'k3s-master' as hostname"
}

REPO_URL="https://github.com/davincibot/clusterconfig.git"
CLONE_DIR="/tmp/clusterconfig"
TARGET_DIR="/etc/nixos"
CURRENT_HOSTNAME=$(hostname)
SOPS_AGE_KEY="/var/lib/sops-nix/key.txt"
HW_CONFIG="/etc/nixos/hardware-configuration.nix"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--hostname)
            if [[ -n "${2:-}" ]]; then
                CURRENT_HOSTNAME="$2"
                shift 2
            else
                echo "[ERROR] Hostname argument is required for -h/--hostname option"
                usage
                exit 1
            fi
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "[INFO] Starting update script..."
echo "[INFO] Using hostname: $CURRENT_HOSTNAME"

# --- Pre-flight checks ---

# Ensure the sops age key is present (required for secret decryption)
if [[ ! -f "$SOPS_AGE_KEY" ]]; then
    echo "[ERROR] sops age key not found at $SOPS_AGE_KEY"
    echo "        Deploy it from your admin machine with:"
    echo "          ssh <host> 'sudo mkdir -p /var/lib/sops-nix && sudo tee /var/lib/sops-nix/key.txt' < key.txt"
    echo "          ssh <host> 'sudo chmod 600 /var/lib/sops-nix/key.txt'"
    exit 1
fi

# Generate hardware-configuration.nix if it doesn't exist yet
if [[ ! -f "$HW_CONFIG" ]]; then
    echo "[INFO] hardware-configuration.nix not found — generating it now..."
    sudo nixos-generate-config --show-hardware-config > /tmp/hw-config.nix
    sudo mv /tmp/hw-config.nix "$HW_CONFIG"
    echo "[INFO] Generated $HW_CONFIG"
else
    echo "[INFO] hardware-configuration.nix already exists, skipping generation."
fi

# --- Clone & copy ---

echo "[INFO] Removing old clone directory: $CLONE_DIR"
rm -rf "$CLONE_DIR"
echo "[INFO] Cloning repository from $REPO_URL to $CLONE_DIR"
git clone "$REPO_URL" "$CLONE_DIR"

# Copy files to /etc/nixos, replacing existing files but preserving hw-config
echo "[INFO] Copying files from $CLONE_DIR to $TARGET_DIR"
sudo cp -rT "$CLONE_DIR" "$TARGET_DIR"

# --- Rebuild ---

echo "[INFO] Rebuilding NixOS configuration for host: $CURRENT_HOSTNAME"
sudo nixos-rebuild switch --flake "${TARGET_DIR}#${CURRENT_HOSTNAME}"

echo "[INFO] Update script completed successfully."