top@{ withSystem, lib, inputs, config, ... }: {
  imports = [
    # dogfooding
    ./flake-module.nix
  ];
  systems = [ "x86_64-linux" "aarch64-linux" ];
  flake = {
    # These aren't system dependent so we define them once. x86_64-linux is unrelated.
    checks.x86_64-linux = {
      evaluation-checks =
        (import ./flake-modules/derivationTree-type.nix { inherit lib; }).tests
          inputs.nixpkgs.legacyPackages.x86_64-linux.emptyFile;

      evaluation-herculesCI =
        let it = (import ./flake-modules/herculesCI-eval-test.nix { inherit inputs; });
        in it.tests inputs.nixpkgs.legacyPackages.x86_64-linux.emptyFile // { debug = it; };

      evaluation-mkHerculesCI =
        let it = (import ./lib/mkHerculesCI-test.nix { inherit inputs; });
        in it.tests inputs.nixpkgs.legacyPackages.x86_64-linux.emptyFile // { debug = it; };

      evaluation-nix-darwin =
        let it = (import ./effects/nix-darwin/eval-test.nix { inherit inputs; });
        in it.tests inputs.nixpkgs.legacyPackages.x86_64-linux.emptyFile // { debug = it; };
    };

    tests = withSystem "x86_64-linux" ({ hci-effects, pkgs, ... }: {
      git-crypt-hook = pkgs.callPackage ./effects/git-crypt-hook/test.nix { };
      # pyjwt is marked insecure; skip
      # nixops = pkgs.callPackage ./effects/nixops/test/default.nix {};
      nix-shell = pkgs.callPackage ./effects/nix-shell/test.nix { };
      nixops2 = pkgs.callPackage ./effects/nixops2/test/default.nix { nixpkgsFlake = inputs.nixpkgs; };
      cachix-deploy = pkgs.callPackage ./effects/cachix-deploy/test.nix { };
      mkEffect = pkgs.callPackage ./effects/effect/test.nix { };
      nixos = hci-effects.callPackage ./effects/nixos/test.nix { };
    });
  };

  hercules-ci.flake-update = {
    enable = true;
    when.dayOfMonth = 15;
    autoMergeMethod = "merge";
  };

  herculesCI = { config, ... }: {

    # We don't have kvm on arm in CI for now.
    ciSystems = [ "x86_64-linux" ];

    onPush.default = {
      outputs.effects =
        let
          pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          tests = top.config.flake.tests // {
            netlifyDeploy = pkgs.callPackage ./effects/netlify/test/default.nix { inherit (config.repo) rev; };
          };
        };
    };
  };

  perSystem = { pkgs, hci-effects, inputs', system, ... }: {
    checks = {
      flake-update = hci-effects.callPackage ./effects/flake-update/test.nix { };
      write-branch = hci-effects.callPackage ./effects/write-branch/test.nix { };
      ssh = hci-effects.callPackage ./effects/ssh/test.nix { };
      artifacts-tool = hci-effects.callPackage ./packages/artifacts-tool/test { };
      artifacts-tool-typecheck = hci-effects.callPackage ./packages/artifacts-tool/mypy.nix { };
      github-releases = (import ./flake-modules/github-releases/test.nix { effectSystem = system; inherit inputs; }).test;
    };
    devShells.default = pkgs.mkShell {
      nativeBuildInputs = [
        pkgs.nixpkgs-fmt
        pkgs.hci
        pkgs.python3Packages.python
        pkgs.python3Packages.mypy
        pkgs.python3Packages.autopep8
      ];
    };

    # Quick and dirty // override. Do not recommend.
    herculesCIEffects.pkgs = pkgs // {
      hci = inputs'.hercules-ci-agent.packages.hercules-ci-cli;
    };
  };
}
