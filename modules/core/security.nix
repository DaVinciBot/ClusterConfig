{ config, pkgs, lib, ... }:

{
  # Kernel Hardening
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "kernel.sysrq" = 0;
  };

  # AppArmor
  security.apparmor.enable = true;

  # Auditd
  security.audit.enable = true;
  security.auditd.enable = true;

  # Sudo Hardening
  security.sudo.execWheelOnly = true;

  # Fail2Ban - Ban IPs that fail SSH login too many times
  services.fail2ban = {
    enable = true;
    # Ban IP for 1 hour after 5 failed attempts
    bantime = "1h"; 
    maxretry = 5;
  };

  # Sops Configuration
  sops.defaultSopsFile = ../../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/var/lib/sops-nix/key.txt"; # Ensure this key exists on the host

  sops.secrets."user_passwords/dvb" = {
    neededForUsers = true;
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowTcpForwarding = false;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowStreamLocalForwarding = false;
      AuthenticationMethods = "publickey";
    };
  };
}