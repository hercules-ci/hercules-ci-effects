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
          systems = [ "aarch64-darwin" "x86_64-linux" ];
          defaultEffectSystem = effectSystem;
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
          ];
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
  ];

  example1Branch = example1.herculesCI (fakeHerculesCI fakeRepoBranch);
  example1Tag = example1.herculesCI (fakeHerculesCI fakeRepoTag);

  test =
    assert example1Branch.onPush.default.outputs.checks.release-artifacts.files
      == expectedFiles;
    assert example1Tag.onPush.default.outputs.checks.release-artifacts.files
      == expectedFiles;

    assert example1Branch.onPush.default.outputs.effects.gh-releases == { };
    assert example1Tag.onPush.default.outputs.effects.gh-releases.isEffect;
    assert example1Tag.onPush.default.outputs.effects.gh-releases.files == expectedFiles;

    # Return the check, so that we can build it in CI
    example1Branch.onPush.default.outputs.checks.release-artifacts;

}
