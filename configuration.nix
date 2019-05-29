# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
let
  etimoCommon = fetchGit https://github.com/etimo/Etimo;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./passwords.nix
      ./vive-virtualization.nix
      ./bootmenu.nix
      (etimoCommon + "/employee-users.nix")
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.cpu.amd.updateMicrocode = true;

  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"

    "pcie_aspm=off"

    "quiet"

    # AMDGPU doesn't like IOMMU + 2 GPUs, it seems
    # try disabling after reserving (at least) one GPU
    # for VFIO
    # "iommu=soft"
  ];

  networking.hostName = "etvrimo"; # Define your hostname.
  networking.networkmanager.enable = true;

  # Select internationalisation properties.
  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "sv-latin1";
    defaultLocale = "sv_SE.UTF-8";
  };

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Human rights
    wget vim tmux git
    # Driver tools
    pciutils usbutils
    # Sensors
    lm_sensors
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.bash.enableCompletion = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    22 # SSH
  ];

  # Define extra user accounts.
  security.sudo.wheelNeedsPassword = false;
  users.users = {
    root.openssh.authorizedKeys.keys = [
      # Teo
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCxxlJ60d00gRVx51KJtUP2gNYIka3uL6r1zF76HIKOP583K4iiSODxPrtVocJHO2CPyCKYeZpEVjCPSS0lHy1meyjQp2rWyOQm61Us5gItiG5yWN0Tfqnv7bjbdbByVedrhlGMLr/bzkOSGqM+yKdbCQnQVjTWuEj4hQ1j0eVCjww4chiYCJ9dgcH2O7C43YEgp//r4/U00AW5Q+RYgDpC7nMm+7cHsE367lciMXXjHabinoZAyitgpnuE0epbc4GSuA94Ai9WPvBd5GSIvLnbR12FESdG5KQDB82TeKi9lBZ1jHzGQl3jyA6q4mokgiA7/bDQQFs9wJcfkEFe9e2J cardno:000606515530"
    ];
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.03"; # Did you read the comment?

  # Speed up Nix builds
  nix.maxJobs = 32;
  nix.buildCores = 16;
  nix.extraOptions =
    ''
      # Always refetch etimoCommon
      tarball-ttl = 0
    '';
}
