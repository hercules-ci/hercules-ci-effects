args@
{ inputs ? hercules-ci-effects.inputs
, hercules-ci-effects ? if args?inputs then inputs.self else builtins.getFlake "git+file://${toString ../..}"
}:
let
  testSupport = import ../../lib/testSupport.nix args;

  # TODO: use a flake.lock, so that we can CI the upstream
  #       also lib.darwinSystem would need follows to inject our own nixpkgs,
  #       so we use the one from the nix-darwin flake for testing here. Awkward.
  darwin = builtins.getFlake "github:LnL7/nix-darwin?rev=87b9d090ad39b25b2400029c64825fc2a8868943";
in
rec {
  inherit (inputs) flake-parts;
  inherit (testSupport) callFlakeOutputs;

  testEqDrv = drv1: drv2:
    if drv1 == drv2 then true
    else builtins.trace "Oh-oh, these are different! Check the differences with\nnix-diff ${drv1} ${drv2}" false;

  flake1 = callFlakeOutputs (inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, self, ... }: {
      imports = [
        ../../flake-module.nix
      ];
      systems = [ "x86_64-linux" ];
      flake = {
        darwinConfigurations."Johns-MacBook" = darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          modules = [ ./test/configuration.nix ];
        };
        test.by-config = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            config = self.darwinConfigurations."Johns-MacBook";
          }
        );
        test.by-other-args = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            system = "x86_64-darwin";
            nix-darwin = darwin.outPath;
            nixpkgs = darwin.inputs.nixpkgs.outPath;
            configuration = ./test/configuration.nix;
          }
        );
      };
    })
  );

  tests = ok:

    # Assumption
    assert flake1.darwinConfigurations."Johns-MacBook".system
      == flake1.darwinConfigurations."Johns-MacBook".config.system.build.toplevel;

    assert 
      testEqDrv flake1.test.by-config.drvPath flake1.test.by-other-args.drvPath;

    ok;

}

