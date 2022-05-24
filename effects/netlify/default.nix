{ lib
, mkEffect
, netlify-cli
}:

{ content
, secretName ? throw ''effects.netlify: You must provide `secretName`, the name of the secret which holds the "${secretField}" field.''
, secretField ? "token"
, siteId
, productionDeployment ? false
}:
let
  deployArgs = [
    "--dir=${content}"
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
