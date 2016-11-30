# Git-CVS Workflow Utilities
# https://github.com/vilic/gcvs

alias gcup="gcvs_update"
alias gcxp="gcvs_export"
alias gccu="gcvs_git_commit_as_cvs_update"
alias gcui="gcvs_update_gitignore"
alias gccl="gcvs_cleanup"

gcvs_init() (
    set -e

    _gcvs_echo "Initializing Git repository..."
    git init
    git config cvsexportcommit.cvsdir .

    _gcvs_echo "Updating .gitignore file..."
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
        local stashed=false
        _gcvs_echo "No local changes to save."
    else
        local stashed=true
    fi

    # Now the file in zon should be untouched.
    _gcvs_echo "Updating CVS repository..."
    cvsup

    _gcvs_echo "Updating .gitignore file..."
    gcvs_update_gitignore

    _gcvs_echo "Staging changes..."
    git add .

    _gcvs_echo "Committing changes..."
    gcvs_git_commit_as_cvs_update || true

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

    _gcvs_echo "Stashing changes..."

    local stash_result=`git stash --include-untracked`

    if [[ $stash_result == *"No local changes to save"* ]]
    then
        local stashed=false
        _gcvs_echo "No local changes to save."
    else
        local stashed=true
    fi

    local branch=`git rev-parse --abbrev-ref HEAD`

    git checkout -q HEAD~1

    local tmp_branch="tmp-$(date +%s)"

    _gcvs_echo "Checking out temporary branch $tmp_branch..."
    git checkout -b $tmp_branch

    _gcvs_echo "Exporting commit to CVS..."
    git cvsexportcommit -p -u -c $branch

    _gcvs_echo "Commit exported successfully."
    _gcvs_echo "Merging changes back to $branch..."

    git add .
    git commit -m "-" || true

    git checkout $branch
    git merge --squash $tmp_branch
    git commit -m "Merge updates triggered by CVS exporting." || true

    _gcvs_echo "Deleting temporary branch..."
    git branch -D $tmp_branch

    if $stashed
    then
        _gcvs_echo "Applying stash..."
        git stash pop
    fi

    _gcvs_echo "Exporting completed."
)

gcvs_git_commit_as_cvs_update() (
    set -e
    git commit -m "CVS Update (`date`)"
)

gcvs_update_gitignore() (
    set -e

    cat .cvsignore > .gitignore
    printf "\n\
CVS/\n\
.#*\n\
.msg\n\
.cvsexportcommit.diff\n\
"\
    >> .gitignore
)

gcvs_cleanup() (
    find . -type f -name '.#*' -delete
    rm -f .msg
    rm -f .cvsexportcommit.diff
)

_gcvs_echo() {
    echo -e "$(tput bold)$1$(tput sgr0)"
}
