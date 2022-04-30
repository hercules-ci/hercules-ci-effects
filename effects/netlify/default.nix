{ lib
, mkEffect
, netlify-cli
}:
args@{ websitePackage ? throw "effects.netlify: You must provide website package to deploy"
, secretName ? throw "effects.netlify: You must provide the name of the secret which holds the appropriate data field"
, secretData ? throw "effects.netlify: You must provide the name of the secret data field which holds the Netlify auth token"
, siteId ? throw "effects.netlify: You must provide a Netlify site ID"
, productionDeployment ? false
}:
let
  deployArgs = [
    "--dir=${websitePackage}"
    "--site=${siteId}"
  ] ++ lib.optionals productionDeployment [ "--prod" ];
in
mkEffect {
  inputs = [ netlify-cli ];
  secretsMap."netlify" = secretName;
  effectScript = ''
    netlify deploy \
      --auth=$(readSecretString netlify .${secretData}) \
      ${lib.escapeShellArgs deployArgs}
  '';
}
