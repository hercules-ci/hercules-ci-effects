{ lib
, mkEffect
, netlify-cli
}:
args@{ websitePackage ? throw "effects.netlify: You must provide website package to deploy"
, secretName ? throw ''effects.netlify: You must provide the name of the secret which holds the "${secretField}" field.''
, secretData ? "token"
, secretField ? secretData
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
      --auth=$(readSecretString netlify .${secretField}) \
      ${lib.escapeShellArgs deployArgs}
  '';
}
