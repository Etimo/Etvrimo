{pkgs, ...}:
{
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
