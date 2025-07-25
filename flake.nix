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
      
      # Import secrets directly (secrets.nix must exist)
      secrets = import /etc/nixos/secrets.nix;
      
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
      mkServerConfig = { serverHostname, serverIP, hddUUID, isMaster ? null, masterIP ? null }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs serverHostname serverIP hddUUID isMaster masterIP secrets;
          inherit (self) outputs;
        };
        modules = [
          # Common modules for all servers
          ./modules/common.nix
          ./modules/server.nix
          ./modules/nvidia.nix
          ./modules/drives.nix

          # Host-specific configuration with variables
          {
            networking.hostName = serverHostname;
            networking.interfaces.eno1.ipv4.addresses = [ {
              address = serverIP;
              prefixLength = 24;
            } ];
            
            # Import hardware configuration from .
            imports = [ /etc/nixos/hardware-configuration.nix ];
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
          hddUUID = "9b28a06f-e9cc-485d-a8ba-d59a6f1c84d4";
          isMaster = true;
          masterIP = "192.168.0.10";  # Self-reference for master
        };

        # K3s Worker node configuration
        rob = mkServerConfig {
          serverHostname = "rob";
          serverIP = "192.168.0.11";
          hddUUID = "eb5fc298-4f97-4c37-87a1-79e57f532df5";
          isMaster = false;
          masterIP = "192.168.0.10";  # Points to flo
        };
        bob = mkServerConfig {
          serverHostname = "bob";
          serverIP = "192.168.0.12";
          hddUUID = "98c08844-c0a7-4b17-b0ed-380641462584";
          isMaster = false;
          masterIP = "192.168.0.10";  # Points to flo
        };

        # Additional worker nodes / blender nodes
        ping = mkServerConfig {
          serverHostname = "ping";
          serverIP = "192.168.0.13";
          hddUUID = "16222caa-fcee-4c0d-9eab-b6abb6a2350c";
        };
        oogway = mkServerConfig {
          serverHostname = "oogway";
          serverIP = "192.168.0.14";
          hddUUID = "006342c8-3bb9-4b9f-8567-89e52a3c203b";
        };
        shifu = mkServerConfig {
          serverHostname = "shifu";
          serverIP = "192.168.0.15";
          hddUUID = "438e198f-c884-4161-9e03-db1bd26ab957";
        };
        monkey = mkServerConfig {
          serverHostname = "monkey";
          serverIP = "192.168.0.16";
          hddUUID = "5e1fdbfd-0f94-4278-9633-da651ad9e90c";
        };
      };
    };
}