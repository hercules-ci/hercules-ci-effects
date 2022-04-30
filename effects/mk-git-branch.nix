/* Push a branchRoot to a git remote. Useful for deploying content via
   git.

   Example:
     mkGitBranchViaEffect {
       pushToBranch = "staging-myWebsite";
       preGitInit = ''
         echo "staging-myWebsite.example.com" > .domains
       '';
       branchRoot = "${./myWebsiteRoot}";
       gitRemote = "git@codeberg.org";
       hostKey = "codeberg.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
       owner = "myName";
       repo = "pages";
       committerEmail = "edolstra@gmail.com";
       committerName = "Hercules-CI Effects";
       authorName = "Hercules-CI Effects";
     };
*/
{
  mkEffect,
  git,
  openssh,
}:
args@{
  gitRemote,
  hostKey,
  pushToBranch,
  owner,
  repo,
  branchRoot,
  committerEmail,
  committerName,
  authorName,
  preGitInit ? "",
  sshSecretName ? "ssh",
  ...
}:
mkEffect {
  inputs = [ openssh git ];
  secretsMap = {
    "ssh" = ${sshSecretName};
  };
  effectScript = ''
    writeSSHKey
    echo ${hostKey} >> ~/.ssh/known_hosts
    export GIT_AUTHOR_NAME="${authorName}"
    export GIT_COMMITTER_NAME="${committerName}"
    export EMAIL="${committerEmail}"
    cp -r --no-preserve=mode ${branchRoot} ./${pushToBranch} && cd ${pushToBranch}
    ${preGitInit}
    git init -b ${pushToBranch}
    git remote add origin ${gitRemote}:${owner}/${repo}.git
    git add .
    git commit -m "Deploy to ${pushToBranch}"
    git push -f origin ${pushToBranch}:${pushToBranch}
  '';
}
