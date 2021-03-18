
gitCryptPostUnpack() {
  (
    echo >&2 'preparing to unlock git-crypt encrypted files'
    cd "$sourceRoot";
    removeDotGit=false
    if ! test -e .git; then
      git init --quiet --initial-branch git-crypt .
      git add .
      git config user.name hercules-ci-effects
      git config user.email support@hercules-ci.com
      git commit -qm 'fake commit in order to run git-crypt without a repo'
      removeDotGit=true
    fi
    git crypt unlock
    if $removeDotGit; then
      rm -rf .git
    fi
  )
}

postUnpackHooks+=(gitCryptPostUnpack)
