{ hci-effects }:

hci-effects.effectVMTest {
  name = "setup";
  effects = {
    setup-check = hci-effects.modularEffect {
      effectScript = ''
      (
        set -x
        : "/bin/sh works"
        /bin/sh -c 'echo "Hello world"' | grep -q "Hello world"
      )
      '';
    };
  };
  testScript = ''
    agent.succeed("effect-setup-check")
  '';
}
