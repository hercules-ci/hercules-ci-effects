# Run with:
#   nix build .#checks.x86_64-linux.artifacts-tool
{ pkgs }:
let
  fake-gh = pkgs.writers.writePython3Bin "gh" { } (builtins.readFile ./fake-gh.py);
  fake-zip = pkgs.writers.writePython3Bin "zip" { } (builtins.readFile ./fake-zip.py);
  artifacts-tool = pkgs.callPackage ../package.nix { };
in
pkgs.runCommandLocal "github-releases-check"
  {
    nativeBuildInputs = [
      artifacts-tool
      fake-gh
      fake-zip
    ];
    passthru = {
      inherit artifacts-tool;
    };
  }
  ''
    set -ex

    export owner=repo_owner
    export repo=repo_name
    export releaseTag=repo_tag
    export skipIfExists=0

    export files='[{"label":"fake-gh","path":"${fake-gh}"}]'
    echo "test should fail: directory"
    artifacts-tool && result=0 || result=1
    if [[ $result != 1 ]]; then
      echo "failed"
      exit 1
    fi
    echo "OK"

    # Each non-check_only test runs in a fresh directory because artifacts-tool
    # creates symlinks and then execlp's gh, leaving artifacts behind.

    export files='[{"label":"fake-gh","path":"${fake-gh}/bin/gh"}]'
    echo "test should succeed: single file"
    workdir=$(mktemp -d)
    pushd "$workdir"
    artifacts-tool && result=0 || result=1
    if [[ $result != 0 ]]; then
      echo "failed"
      exit 1
    fi
    if [[ `cat gh.log` != '["${fake-gh}/bin/gh","release","create","--repo","repo_owner/repo_name","repo_tag","fake-gh"]' ]]; then
      echo "unexpected gh.log:"
      cat gh.log
      echo "failed"
      exit 1
    fi
    popd
    echo "OK"

    # skipIfExists=1, release already exists: should skip without calling release create
    export skipIfExists=1
    export FAKE_GH_RELEASE_EXISTS=1
    echo "test skipIfExists: release exists, should skip"
    workdir=$(mktemp -d)
    pushd "$workdir"
    artifacts-tool && result=0 || result=1
    if [[ $result != 0 ]]; then
      echo "expected success, got failure"
      exit 1
    fi
    # gh.log should only contain the release view call, not release create
    if ! grep -F '"release","view"' gh.log > /dev/null; then
      echo "expected gh release view call"
      cat gh.log
      exit 1
    fi
    if grep -F '"release","create"' gh.log > /dev/null; then
      echo "should not have called gh release create"
      cat gh.log
      exit 1
    fi
    popd
    echo "OK"

    # skipIfExists=1, release does not exist: should proceed with release create
    export FAKE_GH_RELEASE_EXISTS=0
    echo "test skipIfExists: release does not exist, should create"
    workdir=$(mktemp -d)
    pushd "$workdir"
    artifacts-tool && result=0 || result=1
    if [[ $result != 0 ]]; then
      echo "expected success, got failure"
      exit 1
    fi
    # gh.log should contain both the view call and the create call
    if ! grep -F '"release","view"' gh.log > /dev/null; then
      echo "expected gh release view call"
      cat gh.log
      exit 1
    fi
    if ! grep -F '"release","create"' gh.log > /dev/null; then
      echo "expected gh release create call"
      cat gh.log
      exit 1
    fi
    popd
    echo "OK"

    touch $out
  ''
