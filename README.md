# NixOS Cluster Configuration

This repository contains a flake-based NixOS configuration for a K3s cluster with a master node and worker nodes.

## Structure

```
├── flake.nix                    # Main flake configuration with flexible server setup
├── modules/                     # Reusable NixOS modules
│   ├── common.nix              # Shared configuration (users, packages, etc.)
│   ├── server.nix              # Server-specific optimizations
│   ├── nvidia.nix              # NVIDIA driver configuration
│   ├── k3s-master.nix          # K3s master node configuration
│   ├── k3s-node.nix            # K3s worker node configuration
│   └── tunnel.nix              # Tunnel service configuration
├── secrets.nix.template        # Template for sensitive configuration
├── secrets.nix                 # Actual secrets (DO NOT COMMIT TO GIT)
├── hardware-configuration.nix   # Hardware configuration template
└── add-server.sh               # Helper script to add new servers
```

## Usage

### Initial Setup


2. **create secrets.nix** with your actual values based on the template:
   - `k3sToken`: Generate with `openssl rand -base64 32`
   - `tunnel.id` and `tunnel.secret`: Your tunnel credentials
   - `sshKeys`: Your actual SSH public keys
   - `userPasswords`: Generate with `mkpasswd -m yescrypt`

3. **Initialize the flake**:
   ```bash
   nix flake update
   ```

4. **Check the configuration**:
   ```bash
   nix flake check
   ```

### Local Deployment

On each target machine, switch to the new configuration:
```bash
# On master node (dvbar)
sudo nixos-rebuild switch --flake .#dvbar

# On worker node (dvbaguette)  
sudo nixos-rebuild switch --flake .#dvbaguette

# On any custom server
sudo nixos-rebuild switch --flake .#servername
```

### Updating

To update specific inputs:
```bash
nix flake update nixpkgs
nix flake update nixpkgs-unstable
```

## Configuration

### Flexible Server Configuration

The flake now supports a flexible configuration system using the `mkServerConfig` function with these parameters:

- **`serverHostname`**: The hostname for the server
- **`serverIP`**: The IP address of the server
- **`isMaster`**: Boolean - if true, becomes K3s master and enables tunnel service
- **`masterIP`**: IP address of the K3s master (defaults to 192.168.0.10)

### Adding New Servers

Add to `flake.nix` in the `nixosConfigurations` section:
```nix
newserver = mkServerConfig {
  serverHostname = "newserver";
  serverIP = "192.168.0.13";
  isMaster = false;
  masterIP = "192.168.0.10";
};
```

### Server Roles

- **Master nodes** (`isMaster = true`):
  - Run K3s in server mode
  - Enable tunnel service
  - Act as the cluster control plane

- **Worker nodes** (`isMaster = false`):
  - Run K3s in agent mode
  - Connect to the specified master
  - Provide compute resources

### Modifying Modules

The modular structure allows easy customization:

- **common.nix**: Shared configuration across all hosts
- **server.nix**: Server-specific optimizations (headless, watchdog, etc.)
- **nvidia.nix**: NVIDIA driver and CUDA configuration
- **k3s-master.nix**: K3s master node setup
- **k3s-node.nix**: K3s worker node setup
- **tunnel.nix**: Custom tunnel service

### Security

- **Secret Management**: Sensitive data is stored in `secrets.nix` (excluded from git)
- **SSH Authentication**: Password authentication is disabled, key-based only
- **Immutable Users**: Users are immutable by default for security
- **Firewall Configuration**: Proper firewall rules for K3s cluster communication
- **Encrypted Passwords**: User passwords are stored as secure hashes

#### Secret Management

The configuration uses a `secrets.nix` file to store sensitive information:

- **K3s cluster token**: Shared secret for cluster authentication
- **SSH public keys**: User authentication keys
- **Tunnel credentials**: Service tunnel configuration
- **Password hashes**: Secure user password storage

**Important**: Never commit `secrets.nix` to version control!

## Cluster Information

- **Master Node**: dvbar (192.168.0.10)
- **Worker Node**: dvbaguette (192.168.0.12)
- **K3s API**: api.kube (192.168.0.10:6443)
- **Network**: 192.168.0.0/24
- **Gateway**: 192.168.0.1

## Quick Start

1. **Clone**:
   ```bash
   git clone <this-repo>
   cd ClusterConfig
   ```

2. **Edit secrets**:
   ```bash
   # Generate a strong K3s token
   openssl rand -base64 32
   
   # Edit secrets.nix with your actual values
   cp secrets.nix.template secrets.nix
   nano secrets.nix
   ```

4. **Deploy**:
   ```bash
   # Copy to target server
   scp -r . dvb@192.168.0.15:/home/dvb/ClusterConfig
   
   # Deploy on target
   ssh dvb@192.168.0.15 'cd ClusterConfig && sudo nixos-rebuild switch --flake .#newworker'
   ```

## Important Security Notes

- 🔒 **Never commit `secrets.nix` to git**
- 🔑 Generate strong tokens: `openssl rand -base64 32`
- 🛡️ Use proper SSH key management
- 🔐 Store password hashes, not plaintext: `mkpasswd -m yescrypt`