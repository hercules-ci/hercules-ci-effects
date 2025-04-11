{ hci-effects }:

hci-effects.effectVMTest {
  name = "setup";
  effects = {
    setup-check = hci-effects.modularEffect {
      effectScript = ''
      (
        set -x

        : "bash is available"
        bash -c 'echo "Hello world"' | grep -q "Hello world"

        : "/bin/sh works"
        /bin/sh -c 'echo "Hello world"' | grep -q "Hello world"

        : "/usr/bin/env works"
        /usr/bin/env bash -c 'echo "Hello world"' | grep -q "Hello world"
      )
      '';
    };
  };
  testScript = ''
    agent.succeed("effect-setup-check")
  '';
}
