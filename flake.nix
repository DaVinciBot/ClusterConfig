{
  description = "NixOS configuration for dvbar using flakes and deploy-rs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    # Optionally, add other inputs here (e.g., home-manager)
  };

  outputs = { self, nixpkgs, deploy-rs, ... }@inputs: {
    nixosConfigurations.dvbar = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
      ];
    };

    # deploy.nodes.dvbar = {
    #   hostname = "192.168.0.10"; # or your actual hostname
    #   profiles.system = {
    #     user = "dvb"; # the SSH user to deploy as
    #     path = self.nixosConfigurations.dvbar.config.system.build.toplevel;
    #   };
    #   # Optionally, set sshOpts, magicRollback, etc.
    # };
  };
}
