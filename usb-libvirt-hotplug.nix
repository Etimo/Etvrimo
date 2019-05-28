{stdenvNoCC, makeWrapper, lib, libvirt}:
stdenvNoCC.mkDerivation {
  name = "usb-libvirt-hotplug";
  src = ./usb-libvirt-hotplug;
  buildInputs = [ makeWrapper ];
  installPhase =
    ''
      mkdir -p $out/bin
      cp usb-libvirt-hotplug.sh $out/bin/usb-libvirt-hotplug
      wrapProgram $out/bin/usb-libvirt-hotplug --prefix PATH : ${lib.makeBinPath [ libvirt ]}
    '';
}
