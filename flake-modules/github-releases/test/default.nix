{ pkgs }:
let
  fake-gh = pkgs.writers.writePython3Bin "gh" {} (builtins.readFile ./fake-gh.py);
  fake-zip = pkgs.writers.writePython3Bin "zip" {} (builtins.readFile ./fake-zip.py);
  artifacts-checker = pkgs.writers.writePython3Bin "artifacts-checker" {} (builtins.readFile ../effect.py);
in
pkgs.runCommandNoCCLocal "github-releases-check"
{
  buildInputs = [ artifacts-checker fake-gh fake-zip ];
}
''
  set -ex

  export owner=repo_owner
  export repo=repo_name
  export releaseTag=repo_tag

  export files='[{"label":"fake-gh","path":"${fake-gh}"}]'
  echo "test should fail: directory"
  artifacts-checker && result=0 || result=1
  if [[ $result != 1 ]]; then
    echo "failed"
    exit 1
  fi
  echo "OK"

  export files='[{"label":"fake-gh","path":"${fake-gh}/bin/gh"}]'
  echo "test should succeed: single file"
  artifacts-checker && result=0 || result=1
  if [[ $result != 0 ]]; then
    echo "failed"
    exit 1
  fi
  if [[ `cat gh.log` != '["${fake-gh}/bin/gh","release","create","--repo","repo_owner/repo_name","repo_tag","fake-gh"]' ]]; then
    echo "failed"
    exit 1
  fi
  echo "OK"
  touch $out
''
