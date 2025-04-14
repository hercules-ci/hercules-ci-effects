{ hci-effects, modular }:

hci-effects.effectVMTest {
  name = "setup";
  effects = {
    setup-check = 
      let
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
      in
        if modular then
          hci-effects.modularEffect { inherit effectScript; }
        else
          hci-effects.mkEffect { inherit effectScript; };
  };
  testScript = ''
    agent.succeed("effect-setup-check")
  '';
}
