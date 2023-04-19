args@
{ inputs ? hercules-ci-effects.inputs
, hercules-ci-effects ? if args?inputs then inputs.self else builtins.getFlake "git+file://${toString ../..}"
, effectSystem ? builtins.currentSystem
}:
let
  testSupport = import ../../lib/testSupport.nix (
    builtins.intersectAttrs
      { inputs = null; hercules-ci-effects = null; }
      args
  );
in
rec {
  inherit inputs;
  inherit (inputs) flake-parts;
  inherit (testSupport) callFlakeOutputs;

  fakeRepoBranch = {
    branch = "main";
    ref = "refs/heads/main";
    rev = "deadbeef";
    shortRev = "deadbe";
    tag = null;
    remoteHttpUrl = "https://git.forge/repo.git";
    forgeType = "github";
    owner = "test-owner";
    name = "test-repo";
  };
  fakeRepoTag = {
    branch = null;
    ref = "refs/heads/main";
    rev = "deadbeef";
    shortRev = "deadbe";
    tag = "1.0";
    remoteHttpUrl = "https://git.forge/repo.git";
    forgeType = "github";
    owner = "test-owner";
    name = "test-repo";
  };
  fakeHerculesCI = repo: {
    primaryRepo = repo;
    inherit (repo) branch ref tag rev shortRev remoteHttpUrl;
  };

  example1 =
    callFlakeOutputs (inputs:
      flake-parts.lib.mkFlake { inherit inputs; }
        ({ ... }: {
          imports = [
            ../../flake-module.nix
          ];
          systems = [
            "aarch64-darwin"
            "aarch64-linux"
            "x86_64-darwin"
            "x86_64-linux"
          ];
          defaultEffectSystem = effectSystem;
          herculesCI.ciSystems = [ "aarch64-darwin" "x86_64-linux" ];

          hercules-ci.github-releases.files = [
            {
              label = "test label";
              path = builtins.toFile "test-file-name" "test-file-contents";
            }
            {
              label = "another label";
              paths = [
                (builtins.toFile "foo" "bar")
                (builtins.toFile "foobar" "bazqux")
              ];
              archiver = "zip";
            }
            {
              label = "a single file package";
              path = inputs.nixpkgs.legacyPackages.x86_64-linux.writeText "hi" "hello";
            }
          ];
        })
    );

  example2 =
    callFlakeOutputs (inputs:
      flake-parts.lib.mkFlake { inherit inputs; }
        ({ lib, ... }: {
          imports = [
            ../../flake-module.nix
          ];
          systems = [
            "aarch64-darwin"
            "aarch64-linux"
            "x86_64-darwin"
            "x86_64-linux"
          ];
          defaultEffectSystem = effectSystem;
          herculesCI.ciSystems = [ "aarch64-darwin" "x86_64-linux" ];

          hercules-ci.github-releases.filesPerSystem = { config, system, ... }: [
            {
              label = "hello-static-${system}";
              path = lib.getExe config.packages.hello;
            }
          ];
          perSystem = { pkgs, ... }: {
            packages.hello = pkgs.pkgsStatic.hello;
          };
        })
    );

  expectedFiles = [
    {
      label = "test label";
      path = builtins.toFile "test-file-name" "test-file-contents";
    }
    {
      archiver = "zip";
      label = "another label";
      paths = [
        (builtins.toFile "foo" "bar")
        (builtins.toFile "foobar" "bazqux")
      ];
    }
    {
      label = "a single file package";
      path = inputs.nixpkgs.legacyPackages.x86_64-linux.writeText "hi" "hello";
    }
  ];

  example1Branch = example1.herculesCI (fakeHerculesCI fakeRepoBranch);
  example1Tag = example1.herculesCI (fakeHerculesCI fakeRepoTag);

  example2Branch = example2.herculesCI (fakeHerculesCI fakeRepoBranch);
  expectedFiles2 = let inherit (inputs.nixpkgs) lib; in [
    {
      label = "hello-static-aarch64-darwin";
      path = "${inputs.nixpkgs.legacyPackages.aarch64-darwin.pkgsStatic.hello}/bin/hello";
    }
    {
      label = "hello-static-x86_64-linux";
      path = "${inputs.nixpkgs.legacyPackages.x86_64-linux.pkgsStatic.hello}/bin/hello";
    }
  ];

  test =
    assert example1Branch.onPush.default.outputs.checks.release-artifacts.files
      == expectedFiles;
    assert example1Tag.onPush.default.outputs.checks.release-artifacts.files
      == expectedFiles;

    assert example1Branch.onPush.default.outputs.effects.github-releases == { };
    assert example1Tag.onPush.default.outputs.effects.github-releases.isEffect;
    assert example1Tag.onPush.default.outputs.effects.github-releases.files == expectedFiles;

    assert example2Branch.onPush.default.outputs.checks.release-artifacts.files
      == expectedFiles2;

    # Return the checks, so that we can build them in CI
    {
      simple = example1Branch.onPush.default.outputs.checks.release-artifacts;
      perSystem = example2Branch.onPush.default.outputs.checks.release-artifacts;
    };

}
