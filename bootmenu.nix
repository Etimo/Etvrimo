{pkgs, config, lib, ...}:
{
  systemd.services.etvrimo-bootmenu = {
    wantedBy = [ "multi-user.target" ];
    conflicts = [ "getty@tty1.service" ];
    script =
    ''
      ${pkgs.cowsay}/bin/cowsay -f dragon-and-cow "Welcome to Etvrimo!"
      echo "Press [P] To Play!" | ${pkgs.figlet}/bin/figlet | ${pkgs.lolcat}/bin/lolcat --truecolor
      echo "Note: You will need to unplug and replug the USB connector for each Vive Link Box after the VMs have started"
      echo "Press Ctrl+Alt+F2 to access the management terminal"

      read -N 1 -s action
      case $action in
      p | P)
        ${lib.concatMapStringsSep "\n" (device: "${pkgs.libvirt}/bin/virsh start ${device.vm}") config.etvrimo.vive.devices}
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
