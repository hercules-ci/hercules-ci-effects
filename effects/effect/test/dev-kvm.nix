{ modularEffect }:

modularEffect {
  effectScript = ''
    echo Checking /dev/kvm access
    stat /dev/kvm || :
    test -r /dev/kvm
  '';
  mounts."/dev/kvm" = "kvm";
}
