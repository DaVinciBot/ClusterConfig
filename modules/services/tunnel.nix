{ config, pkgs, lib, ... }:

let
  cfg = config.services.clusterTunnel;
in {
  options.services.clusterTunnel = {
    secretName = lib.mkOption {
      type = lib.types.str;
      default = "tunnel";
      description = "Name of the sops secret group for the tunnel";
    };
  };

  config = {
    # Tunnel service configuration

    sops.secrets."${cfg.secretName}/id" = {};
    sops.secrets."${cfg.secretName}/secret" = {};
    sops.secrets."${cfg.secretName}/endpoint" = {};

    # Launch tunnel on boot
    systemd.services.launch = {
      description = "Launch Tunnel Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "launch-script" ''
          #!/bin/sh
          ID=$(cat ${config.sops.secrets."${cfg.secretName}/id".path})
          SECRET=$(cat ${config.sops.secrets."${cfg.secretName}/secret".path})
          ENDPOINT=$(cat ${config.sops.secrets."${cfg.secretName}/endpoint".path})
          /root/newt --id "$ID" --secret "$SECRET" --endpoint "$ENDPOINT"
        ''}";
      };
    };
  };
}
