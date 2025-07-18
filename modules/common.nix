{ config, pkgs, lib, secrets, ... }:

{
  # Bootloader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking base configuration
  networking.networkmanager.enable = true;
  networking.defaultGateway = "192.168.0.1";
  networking.nameservers = ["8.8.8.8" "8.8.4.4"];

  # Locale and timezone
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Console and X11 keyboard layout
  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };
  console.keyMap = "fr";

  # User configuration
  users.users.dvb = {
    isNormalUser = true;
    description = "DVB";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
    hashedPassword = secrets.userPasswords.dvb;
    openssh.authorizedKeys.keys = [
      # DVB public key
      secrets.sshKeys.dvb
      # Urbain's public key - Remove if not president anymore
      secrets.sshKeys.urbain
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System packages
  environment.systemPackages = with pkgs; [
    git
    pciutils
    python3
    neofetch
    tmux
    wget
    screen
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # SSH configuration
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # Docker configuration
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    data-root = "/home/dvb/docker";
  };

  # Set system state version
  system.stateVersion = "24.11";
}
