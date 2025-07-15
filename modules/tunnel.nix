{ config, pkgs, lib, secrets, ... }:

{
  # Tunnel service configuration
  
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
        /root/newt --id ${secrets.tunnel.id} --secret ${secrets.tunnel.secret} --endpoint ${secrets.tunnel.endpoint}
      ''}";
    };
  };
}
