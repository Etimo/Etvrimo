# Set up Libvirt with Vive USB forwarding, as well as any required kernel modules
{pkgs, lib, config, ...}:
{
  options = {
    etvrimo = {
      vive = {
        usbSubdevices = lib.mkOption {
          type = lib.types.listOf (lib.types.listOf lib.types.int);
          default = [
            [ 1 1 ]
            [ 1 2 ]
            [ 1 5 ]
            [ 1 6 ]
            [ 1 7 ]
            [ 2 ]
          ];
          description =
            ''
              HTC Vives expose many separate subdevices, connected on two hubs (one in the link box, one in the headset)
              QEMU gets confused if we ask it to forward hubs, so instead we need to enumerate the subdevices and
              enable forwarding individually.

              You can enumerate the USB port tree by running `lsusb -t`. This list contains the "Port" number.

              You'll probably need to change this if you're trying to use a different headset than the original HTC Vive.
            '';
        };

        gpuProductIds = lib.mkOption {
          type = lib.types.listOf lib.types.string;
          description =
            ''
              PCI-E vendor-/product IDs that should be reserved for forwarding.
              Look up the vendor and product IDs for your GPU using `lspci -nn`
              For example, the AMD Vega 56 exposes two PCI devices: Video (1002:687f) and Audio (1002:aaf8)
            '';
          default = [];
        };

        devices = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              pciPath = lib.mkOption {
                type = lib.types.string;
                description =
                  ''
                    The PCI path to the USB controller that the Vive Link Box is connected to. The path
                    will exist on the file system, and is relative to /sys/devices.

                    You can find it by locating the ID of the USB controller with `lspci`, and then using `lspci -t`
                    to find the full path.
                  '';
              };
              usbBus = lib.mkOption {
                type = lib.types.int;
                description =
                  ''
                    You can find the USB bus by locating the root device that the Vive Link Box is connected to in the
                    output of `lsusb -t`.

                    Note that your computer may have multiple USB controllers, which are not interchangeable.

                    # Find the usbBus and usbPath by locating the Vive Link Box's emulated hub in the output of `lsusb -t`.
                    # usbbus is the top-level bus, and usbPath is the path of port numbers down to the hub (not including the root hub).
                    # Note that this path ultimately identifies a single USB port on the computer.
                  '';
              };
              usbPath = lib.mkOption {
                type = lib.types.listOf lib.types.int;
                description =
                  ''
                    You can find the USB path by following the Ports from the root hub to the Vive Link Box's virtual hub
                    in the output of `lsusb -t`. Note that this does *not* include the root hub's own Port (which will
                    always be 1).

                    Also note that the (usbBus, usbPath) tuple identifies a single physical USB port on the computer, so
                    the link box will always have to be plugged into the same port.
                  '';
              };
              vm = lib.mkOption {
                type = lib.types.string;
                description =
                  ''
                    The name of the Libvirt VM that the USB devices should be forwarded to.
                  '';
              };
            };
          });
          default = [];
        };
      };
    };
  };

  config = {
    virtualisation.libvirtd.enable = true;

    # PCI-E forwarding on Ryzen is still fairly experimental, and requires a recent kernel
    boot.kernelPackages = pkgs.linuxPackages_latest;

    boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" "vfio_virqfd" ];
    boot.extraModprobeConfig =
      ''
        # Reserve the GPUs for VMs
        options vfio-pci ids=${lib.concatStringsSep "," config.etvrimo.vive.gpuProductIds}

        # Required for Windows 10 1803+ to boot: https://www.reddit.com/r/VFIO/comments/8gdbnm/ryzen_2700_system_thread_exception_not_handled/dyo2yab/
        options kvm ignore_msrs=1
      '';

    # Forward Vive devices to the corresponding VM
    services.udev.extraRules =
      let
        usb-libvirt-hotplug = pkgs.callPackage ./usb-libvirt-hotplug.nix {};
        runUsbLibvirtHotplug = "${usb-libvirt-hotplug}/bin/usb-libvirt-hotplug";
        # Generates a list of all prefix sublists: [a] -> [[a]]
        # Example: prefixes [ 1 2 3 ] -> [ [ 1 ] [ 1 2 ] [ 1 2 3 ] ]
        prefixes = list: lib.genList (n: lib.take (n + 1) list) (lib.length list);
        usbName = bus: path: toString bus + "-" + lib.concatMapStringsSep "." toString path;
        usbPath = bus: path: "usb${toString bus}/" + lib.concatStringsSep "/" (map (usbName bus) (prefixes path));
        hotplugUsbDevice = vm: pciPath: usbBus: usbSubpath:
          ''SUBSYSTEM=="usb",DEVPATH=="/devices/${pciPath}/${usbPath usbBus usbSubpath}",RUN+="${runUsbLibvirtHotplug} ${vm}"'';
        hotplugVive = device: lib.concatMapStringsSep "\n" (usbSubpath: hotplugUsbDevice device.vm device.pciPath device.usbBus (device.usbPath ++ usbSubpath)) config.etvrimo.vive.usbSubdevices;
      in lib.concatMapStringsSep "\n" hotplugVive config.etvrimo.vive.devices;
  };
}
