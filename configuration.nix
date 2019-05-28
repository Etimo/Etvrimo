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
      (etimoCommon + "/employee-users.nix")
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  #boot.kernelPackages = pkgs.linuxPackages_4_18;
  #boot.kernelPackages = pkgs.linuxPackages_testing;
  boot.kernelPackages = pkgs.linuxPackages_latest;

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

  boot.extraModprobeConfig =
    ''
      # Reserve the GPUs for VMs
      options vfio-pci ids=1002:687f,1002:aaf8

      # Required for Windows 10 1803+ to boot: https://www.reddit.com/r/VFIO/comments/8gdbnm/ryzen_2700_system_thread_exception_not_handled/dyo2yab/
      options kvm ignore_msrs=1
    '';
  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" "vfio_virqfd" ];

  networking.hostName = "etvrimo"; # Define your hostname.
  networking.networkmanager.enable = true;
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

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
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    22 # SSH
  ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable touchpad support.
  # services.xserver.libinput.enable = true;

  virtualisation.libvirtd.enable = true;

  # Enable the KDE Desktop Environment.
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Define a user account.
  security.sudo.wheelNeedsPassword = false;
  users.users = {
    root.openssh.authorizedKeys.keys = [
      # Teo
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCxxlJ60d00gRVx51KJtUP2gNYIka3uL6r1zF76HIKOP583K4iiSODxPrtVocJHO2CPyCKYeZpEVjCPSS0lHy1meyjQp2rWyOQm61Us5gItiG5yWN0Tfqnv7bjbdbByVedrhlGMLr/bzkOSGqM+yKdbCQnQVjTWuEj4hQ1j0eVCjww4chiYCJ9dgcH2O7C43YEgp//r4/U00AW5Q+RYgDpC7nMm+7cHsE367lciMXXjHabinoZAyitgpnuE0epbc4GSuA94Ai9WPvBd5GSIvLnbR12FESdG5KQDB82TeKi9lBZ1jHzGQl3jyA6q4mokgiA7/bDQQFs9wJcfkEFe9e2J cardno:000606515530"
    ];

    teo-buildslave = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL89Iw6jZFM3TgQN+09aC3pFSad8tn72oHCfUyikMzyD root@teo-etimo"
      ];
    };
  };

  security.wrappers.play-vr = {
    source = pkgs.writeScript "play-vr"
      ''
        #!/usr/bin/env bash
        set -euo pipefail
        for vm in Etvrimo{,-2}; do
          ${pkgs.libvirt}/bin/virsh start $vm
        done
      '';
    owner = "root";
    group = "root";
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.03"; # Did you read the comment?

  # Forward Vive devices to the corresponding VM
  services.udev.extraRules =
    let
      usb-libvirt-hotplug = pkgs.stdenvNoCC.mkDerivation {
        name = "usb-libvirt-hotplug";
        src = ./usb-libvirt-hotplug;
        buildInputs = [ pkgs.makeWrapper ];
        installPhase =
          ''
            mkdir -p $out/bin
            cp usb-libvirt-hotplug.sh $out/bin/usb-libvirt-hotplug
            wrapProgram $out/bin/usb-libvirt-hotplug --prefix PATH : ${lib.makeBinPath [ pkgs.libvirt ]}
          '';
      };
      runUsbLibvirtHotplug = "${usb-libvirt-hotplug}/bin/usb-libvirt-hotplug";
      # Generates a list of all prefix sublists: [a] -> [[a]]
      # Example: prefixes [ 1 2 3 ] -> [ [ 1 ] [ 1 2 ] [ 1 2 3 ] ]
      prefixes = list: lib.genList (n: lib.take (n + 1) list) (lib.length list);
      usbName = bus: path: toString bus + "-" + lib.concatMapStringsSep "." toString path;
      usbPath = bus: path: "usb${toString bus}/" + lib.concatStringsSep "/" (map (usbName bus) (prefixes path));
      hotplugUsbDevice = vm: pciPath: usbBus: usbSubpath:
        ''SUBSYSTEM=="usb",DEVPATH=="/devices/${pciPath}/${usbPath usbBus usbSubpath}",RUN+="${runUsbLibvirtHotplug} ${vm}"'';
      viveHotplugSubdevices = [
        [ 1 1 ]
        [ 1 2 ]
        [ 1 5 ]
        [ 1 6 ]
        [ 1 7 ]
        [ 2 ]
      ];
      hotplugVive = vm: pciPath: usbBus: usbPath: lib.concatMapStringsSep "\n" (usbSubpath: hotplugUsbDevice vm pciPath usbBus (usbPath ++ usbSubpath)) viveHotplugSubdevices;
    in ''
      # Next to the USB-C port: Vive 1
      # Should include all non-hub subdevices
      ${hotplugVive "Etvrimo" "pci0000:00/0000:00:01.3/0000:01:00.0" 1 [ 5 ]}

      # Front left USB port: Vive 2
      # Should include all non-hub subdevices
      ${hotplugVive "Etvrimo-2" "pci0000:00/0000:00:01.3/0000:01:00.0" 1 [ 4 ]}

      #SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:07.1/0000:0e:00.3/usb5/5-4/5-4.1/5-4.1.1",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      #SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:07.1/0000:0e:00.3/usb5/5-4/5-4.1/5-4.1.2",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      #SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:07.1/0000:0e:00.3/usb5/5-4/5-4.1/5-4.1.5",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      #SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:07.1/0000:0e:00.3/usb5/5-4/5-4.1/5-4.1.6",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      #SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:07.1/0000:0e:00.3/usb5/5-4/5-4.1/5-4.1.7",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      #SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:07.1/0000:0e:00.3/usb5/5-4/5-4.2",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      #SUBSYSTEM=="usb",DEVPATH=="/bus/usb/devices/5-4.1.1",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      # SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:01.3/0000:01:00.0/usb1/5-4/5-4.1/5-4.1.1",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      # SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:01.3/0000:01:00.0/usb1/5-4/5-4.1/5-4.1.2",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      # SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:01.3/0000:01:00.0/usb1/5-4/5-4.1/5-4.1.5",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      # SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:01.3/0000:01:00.0/usb1/5-4/5-4.1/5-4.1.6",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      # SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:01.3/0000:01:00.0/usb1/5-4/5-4.1/5-4.1.7",RUN+="${runUsbLibvirtHotplug} Etvrimo"
      # SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:01.3/0000:01:00.0/usb1/5-4/5-4.2",RUN+="${runUsbLibvirtHotplug} Etvrimo"
    '';

  nix.maxJobs = 32;
  nix.buildCores = 16;
  nix.extraOptions =
    ''
      # Always refetch etimoCommon
      tarball-ttl = 0
    '';

  systemd.services.etvrimo-bootmenu = {
    wantedBy = [ "multi-user.target" ];
    conflicts = [ "getty@tty1.service" ];
    script =
    ''
      ${pkgs.cowsay}/bin/cowsay -f dragon-and-cow "Welcome to Etvrimo!"
      echo "Press [P] To Play!" | ${pkgs.figlet}/bin/figlet | ${pkgs.lolcat}/bin/lolcat --truecolor
      echo "Press Ctrl+Alt+F2 to access the management terminal"

      read -N 1 -s action
      case $action in
      p | P)
        ${pkgs.libvirt}/bin/virsh start Etvrimo
        ${pkgs.libvirt}/bin/virsh start Etvrimo-2
      esac
    '';
    # Run on TTY1
    serviceConfig = {
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVTDisallocate = true;
      Restart = "always";
      RestartSec = "0ms";
    };
    unitConfig = {
      StartLimitIntervalSec = "0";
    };
  };
}
