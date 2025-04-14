{ hci-effects }:

hci-effects.effectVMTest {
  name = "uid";
  effects = {
    uid-check = hci-effects.modularEffect {
      uid = 123;
      gid = 456;
      effectScript = ''
      (
        set -x
        : "Checking UID"
        test "$(id -u)" -eq 123
        : "Checking GID"
        test "$(id -g)" -eq 456
      )
      '';
    };
  };
  testScript = ''
    agent.succeed("effect-uid-check")
  '';
}
