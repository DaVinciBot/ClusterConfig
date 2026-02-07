{ config, pkgs, lib, ... }:

{
  # Tunnel service configuration
  
  sops.secrets."tunnel/id" = {};
  sops.secrets."tunnel/secret" = {};
  sops.secrets."tunnel/endpoint" = {};
  
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
        ID=$(cat ${config.sops.secrets."tunnel/id".path})
        SECRET=$(cat ${config.sops.secrets."tunnel/secret".path})
        ENDPOINT=$(cat ${config.sops.secrets."tunnel/endpoint".path})
        /root/newt --id "$ID" --secret "$SECRET" --endpoint "$ENDPOINT"
      ''}";
    };
  };
}
