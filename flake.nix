{
  description = "NixOS cluster configuration with K3s using flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Flake utilities
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils, ... }@inputs:
    let
      system = "x86_64-linux";
      
      # Import secrets (will fall back to template if secrets.nix doesn't exist)
      secrets = if builtins.pathExists ./secrets.nix 
                then import ./secrets.nix 
                else {
                  k3sToken = "PLACEHOLDER_TOKEN_CHANGE_ME";
                  tunnel = { id = "PLACEHOLDER"; secret = "PLACEHOLDER"; endpoint = "https://pangolin.davincibot.fr"; };
                  sshKeys = { dvb = "PLACEHOLDER_SSH_KEY"; urbain = "PLACEHOLDER_SSH_KEY"; };
                  userPasswords = { dvb = "PLACEHOLDER_PASSWORD_HASH"; };
                };
      
      # Overlay to add unstable packages when needed
      overlays = [
        (final: prev: {
          unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        })
      ];
      
      # Function to create a NixOS configuration for any server
      mkServerConfig = { serverHostname, serverIP, isMaster ? null, masterIP ? null }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs serverHostname serverIP isMaster masterIP secrets;
          inherit (self) outputs;
        };
        modules = [
          # Common modules for all servers
          ./modules/common.nix
          ./modules/server.nix
          ./modules/nvidia.nix
          
          # Host-specific configuration with variables
          {
            networking.hostName = serverHostname;
            networking.interfaces.eno1.ipv4.addresses = [ {
              address = serverIP;
              prefixLength = 24;
            } ];
            
            # Import hardware configuration
            imports = [ ./hardware-configuration.nix ];
          }
          
          # Apply overlays
          { nixpkgs.overlays = overlays; }
        ] ++ 
        # Only include k3s modules if isMaster and masterIP are defined
        (if isMaster != null && masterIP != null then [
          # Conditional modules based on server role
          (if isMaster then ./modules/k3s-master.nix else ./modules/k3s-node.nix)
        ] else []) ++
        # Only include tunnel module if isMaster is true
        (if isMaster == true then [ ./modules/tunnel.nix ] else []);
      };
      
    in {
      # NixOS configurations using the flexible function
      nixosConfigurations = {
        # Master node configuration
        flo = mkServerConfig {
          serverHostname = "flo";
          serverIP = "192.168.0.10";
          isMaster = true;
          masterIP = "192.168.0.10";  # Self-reference for master
        };

        # K3s Worker node configuration
        rob = mkServerConfig {
          serverHostname = "rob";
          serverIP = "192.168.0.11";
          isMaster = false;
          masterIP = "192.168.0.10";  # Points to flo
        };
        bob = mkServerConfig {
          serverHostname = "bob";
          serverIP = "192.168.0.12";
          isMaster = false;
          masterIP = "192.168.0.10";  # Points to flo
        };

        # Additional worker nodes / blender nodes
        ping = mkServerConfig {
          serverHostname = "ping";
          serverIP = "192.168.0.13";
        };
        oogway = mkServerConfig {
          serverHostname = "oogway";
          serverIP = "192.168.0.14";
        };
        shifu = mkServerConfig {
          serverHostname = "shifu";
          serverIP = "192.168.0.15";
        };
        monkey = mkServerConfig {
          serverHostname = "monkey";
          serverIP = "192.168.0.16";
        };
      };
    };
}