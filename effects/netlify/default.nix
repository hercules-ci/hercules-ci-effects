{ lib
, mkEffect
, netlify-cli
}:
args@
{ content ? websitePackage
, websitePackage ? throw "effects.netlify: You must provide the `content` parameter, which is a directory to deploy."
, secretName ? throw ''effects.netlify: You must provide `secretName` the name of the secret which holds the "${secretField}" field.''
, secretData ? "token"
, secretField ? secretData
, siteId
, productionDeployment ? false
}:
let
  deployArgs = [
    "--dir=${content}"
    "--site=${siteId}"
  ] ++ lib.optionals productionDeployment [ "--prod" ];
in
lib.warnIf (args?websitePackage) "effects.netlify: Use the `content` parameter instead of `websitePackage`."
lib.warnIf (args?secretData) ''effects.netlify: Use the `secretField` parameter instead of `secretData`, or rely on the default field name: "token".''
mkEffect {
  inputs = [ netlify-cli ];
  secretsMap."netlify" = secretName;
  effectScript = ''
    netlify deploy \
      --auth=$(readSecretString netlify .${secretField}) \
      ${lib.escapeShellArgs deployArgs}
  '';
}
