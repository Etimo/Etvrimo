# Set up Libvirt, as well as any required kernel modules
{pkgs, lib, ...}:
{
  virtualisation.libvirtd.enable = true;

  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" "vfio_virqfd" ];
  boot.extraModprobeConfig =
    ''
      # Reserve the GPUs for VMs
      # Look up the vendor and product IDs for your GPU using `lspci -nn`
      # AMD Vega 56 exposes two PCI devices: Video (1002:687f) and Audio (1002:aaf8)
      options vfio-pci ids=1002:687f,1002:aaf8

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
      # HTC Vives expose many separate subdevices, connected on two hubs (one in the link box, one in the headset)
      # QEMU gets confused if we ask it to forward hubs, so instead we need to enumerate the subdevices and
      # enable forwarding individually.
      # You can enumerate the USB port tree by running `lsusb -t`. This list contains the "Port" number.
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
}
