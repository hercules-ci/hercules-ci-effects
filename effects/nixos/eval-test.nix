args@
{ inputs ? hercules-ci-effects.inputs
, hercules-ci-effects ? if args?inputs then inputs.self else builtins.getFlake "git+file://${toString ../..}"
}:
let
  testSupport = import ../../lib/testSupport.nix args;

in
rec {
  inherit testSupport;
  inherit (inputs) flake-parts;
  inherit (testSupport) callFlakeOutputs testEqDrv;
  inherit (inputs.nixpkgs) lib;

  isEffect = x: x.isEffect == true && lib.isString x.drvPath;

  flake1 = callFlakeOutputs (inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, self, ... }: {
      imports = [
        ../../flake-module.nix
      ];
      systems = [ "x86_64-linux" ];
      flake = {
        nixosConfigurations."john.lan" = inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./test/configuration.nix ];
        };
        test.by-nixosConfigurations = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixOS {
            ssh.destination = "john.local";
            configuration = self.nixosConfigurations."john.lan";
          }
        );
        test.by-configuration-file = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixOS {
            ssh.destination = "john.local";
            # not recommended if you have proper nixosConfigurations to pull from
            configuration = ./test/configuration.nix;
          }
        );
        test.by-configuration-file-buildOnDestination = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixOS {
            ssh.destination = "john.local";
            ssh.buildOnDestination = true;
            # not recommended if you have proper nixosConfigurations to pull from
            configuration = ./test/configuration.nix;
          }
        );
        test.by-nixosConfigurations-no-buildOnDestination = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixOS {
            ssh.destination = "john.local";
            ssh.buildOnDestination = false;
            configuration = self.nixosConfigurations."john.lan";
          }
        );
        test.by-nixosConfigurations-buildOnDestination = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixOS {
            ssh.destination = "john.local";
            ssh.buildOnDestination = true;
            configuration = self.nixosConfigurations."john.lan";
          }
        );
        test.by-nixosConfigurations-buildOnDestination-override = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixOS {
            ssh.destination = "john.local";
            ssh.buildOnDestination = false;
            buildOnDestination = true;
            configuration = self.nixosConfigurations."john.lan";
          }
        );
      };
    })
  );

  tests = ok:

    # Check some invocations to make sure the glue code evaluates without error.
    assert
      isEffect flake1.test.by-nixosConfigurations;
    assert
      testEqDrv
        flake1.test.by-nixosConfigurations.drvPath
        flake1.test.by-nixosConfigurations-no-buildOnDestination.drvPath;
    assert
      isEffect flake1.test.by-configuration-file;
    assert
      isEffect flake1.test.by-configuration-file-buildOnDestination;
    assert
      testEqDrv
        flake1.test.by-nixosConfigurations-buildOnDestination.drvPath
        flake1.test.by-nixosConfigurations-buildOnDestination-override.drvPath;

    ok;

}

