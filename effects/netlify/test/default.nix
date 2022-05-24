{ pkgs, rev, runCommand }:
let
  domain = "stunning-fiesta.netlify.app";
  baseUrl = "https://${domain}";

  effects = import ../../default.nix effects pkgs;
  inherit (effects) netlifyDeploy;
in
(netlifyDeploy {
  siteId = "6c698c4a-1e1d-44a1-8b1c-6207de7877a5";
  secretName = "netlify-test-account";
  productionDeployment = true;
  content = runCommand "dummy-site" {} ''
    mkdir -p $out/foo
    echo "<h1>hi</h1>${rev}" >$out/index.html
    echo "<h1>bar</h1>${rev}" >$out/foo/index.html
  '';
}).overrideAttrs(eff: {
  effectCheckScript = ''
    set -x

    r="$(curl -v ${baseUrl})"
    [[ "$r" == "<h1>hi</h1>${rev}" ]]

    r="$(curl -v ${baseUrl}/foo)"
    [[ "$r" == "<h1>bar</h1>${rev}" ]]

    set +x
    echo 'All good!'
  '';
})
