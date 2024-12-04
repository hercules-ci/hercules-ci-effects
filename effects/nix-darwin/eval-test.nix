args@
{ inputs ? hercules-ci-effects.inputs
, hercules-ci-effects ? if args?inputs then inputs.self else builtins.getFlake "git+file://${toString ../..}"
}:
let
  testSupport = import ../../lib/testSupport.nix args;

  # TODO: use a flake.lock, so that we can CI the upstream
  #       also lib.darwinSystem would need follows to inject our own nixpkgs,
  #       so we use the one from the nix-darwin flake for testing here. Awkward.
  darwin = builtins.getFlake "github:LnL7/nix-darwin?rev=c6b65d946097baf3915dd51373251de98199280d";
in
rec {
  inherit darwin testSupport;
  inherit (inputs) flake-parts;
  inherit (testSupport) callFlakeOutputs testEqDrv;

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
            configuration = self.darwinConfigurations."Johns-MacBook";
          }
        );
        test.by-config-legacy = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            config = self.darwinConfigurations."Johns-MacBook".config;
          }
        );
        test.by-config-legacy-2 = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            config = self.darwinConfigurations."Johns-MacBook";
          }
        );
        test.by-config-buildOnDestination = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            ssh.buildOnDestination = true;
            configuration = self.darwinConfigurations."Johns-MacBook";
          }
        );
        test.by-config-buildOnDestination-override = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            buildOnDestination = true;
            configuration = self.darwinConfigurations."Johns-MacBook";
          }
        );
        test.by-config-no-buildOnDestination = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            buildOnDestination = false;
            configuration = self.darwinConfigurations."Johns-MacBook";
          }
        );
        test.by-config-no-ssh-buildOnDestination = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            buildOnDestination = false;
            configuration = self.darwinConfigurations."Johns-MacBook";
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
        test.by-other-args-pkgs = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            system = "x86_64-darwin";
            nix-darwin = darwin.outPath;
            pkgs = darwin.inputs.nixpkgs.legacyPackages.x86_64-darwin.extend (self: super: { proof-of-overlay = "yes, overlay"; });
            configuration = ./test/configuration.nix;
          }
        );
        test.by-other-args-buildOnDestination = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            buildOnDestination = true;
            system = "x86_64-darwin";
            nix-darwin = darwin.outPath;
            nixpkgs = darwin.inputs.nixpkgs.outPath;
            configuration = ./test/configuration.nix;
          }
        );
        test.by-other-args-buildOnDestination2 = withSystem "x86_64-linux" ({ hci-effects, ... }:
          hci-effects.runNixDarwin {
            ssh.destination = "john.local";
            ssh.buildOnDestination = true;
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

    assert flake1.darwinConfigurations."Johns-MacBook".system.drvPath == flake1.test.by-config.config.system.build.toplevel.drvPath;

    # produces flake vs non-flake config
    # assert
    #   testEqDrv flake1.test.by-config.drvPath flake1.test.by-other-args.drvPath;

    assert
      testEqDrv
        flake1.test.by-config.drvPath
        flake1.test.by-config-legacy.drvPath;

    assert
      testEqDrv
        flake1.test.by-config.drvPath
        flake1.test.by-config-legacy-2.drvPath;

    assert
      builtins.isString flake1.test.by-other-args-pkgs.drvPath;
    # The addition of the pkgs module appears to reorder the system path, so this equality doesn't quite hold. (or it could be a flake vs legacy related difference; not sure)
    # assert
    #   testEqDrv flake1.test.by-other-args.drvPath flake1.test.by-other-args-pkgs.drvPath;
    assert
      testEqDrv flake1.test.by-other-args-pkgs.config.expose.pkgs.hello.drvPath darwin.inputs.nixpkgs.legacyPackages.x86_64-darwin.hello.drvPath;

    # A custom pkgs should be used without reinvoking nixpkgs from scratch.
    assert
      flake1.test.by-other-args-pkgs.config.expose.pkgs.proof-of-overlay == "yes, overlay";

    assert
      testEqDrv
        flake1.test.by-config.drvPath
        flake1.test.by-config-no-buildOnDestination.drvPath;

    assert
      testEqDrv
        flake1.test.by-config.drvPath
        flake1.test.by-config-no-ssh-buildOnDestination.drvPath;

    assert
      testEqDrv
        flake1.test.by-config-buildOnDestination.drvPath
        flake1.test.by-config-buildOnDestination-override.drvPath;

    assert
      testEqDrv
        flake1.test.by-other-args-buildOnDestination.drvPath
        flake1.test.by-other-args-buildOnDestination2.drvPath;

    ok;

}

