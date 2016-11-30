# Git-CVS Workflow Utilities
# https://github.com/vilic/gcvs

alias gcup="gcvs_update"
alias gcep="gcvs_export"
alias gccu="gcvs_git_commit_as_cvs_update"
alias gcui="gcvs_update_gitignore"

gcvs_init() (
    set -e

    _gcvs_echo "Initializing Git repository..."
    git init
    git config cvsexportcommit.cvsdir .

    gcvs_update_gitignore

    _gcvs_echo "Processing initial commit..."
    git add .
    git commit -am "Initial commit"

    _gcvs_echo "Repository initialized."
)

gcvs_update() (
    set -e

    _gcvs_echo "Stashing changes..."

    local stash_result=`git stash --include-untracked`

    if [[ $stash_result == *"No local changes to save"* ]]
    then
        stashed=false
        _gcvs_echo "No local changes to save."
    else
        stashed=true
    fi

    # Now the file in zon should be untouched.
    _gcvs_echo "Updating CVS repository..."
    cvsup

    gcvs_update_gitignore

    _gcvs_echo "Staging changes..."
    git add .

    gcvs_git_commit_as_cvs_update

    # Apply stash only if there is something saved
    if $stashed
    then
        _gcvs_echo "Applying stash..."
        git stash pop
    fi

    _gcvs_echo "Repository updated."
)

gcvs_export() (
    set -e

    local last_commit_message=`git log -1 --pretty=%B`

    if [[ $last_commit_message == "CVS Update"* ]]
    then
        _gcvs_echo "Current commit is a CVS update commit, exporting aborted."
        exit 1
    fi

    _gcvs_echo "Exporting commit to CVS..."
    git cvsexportcommit -u -p -c -W HEAD
)

gcvs_git_commit_as_cvs_update() (
    set -e

    _gcvs_echo "Committing changes..."
    git commit -m "CVS Update (`date`)"
)

gcvs_update_gitignore() (
    set -e

    _gcvs_echo "Updating .gitignore file..."
    cat .cvsignore > .gitignore
    printf "\nCVS/\n.#*\n" >> .gitignore
)

_gcvs_echo() {
    echo -e "$(tput bold)$1$(tput sgr0)"
}
