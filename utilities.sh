# Git-CVS Workflow Utilities
# https://github.com/vilic/gcvs

alias gcup="gcvs_update"
alias gcxp="gcvs_export"
alias gcxpc="gcvs_export_continue"
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

# TODO: add an exported commits list, and if a commit is not exported, do
# something like rebase.
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
    git commit -m "CVS update" || true

    # Apply stash only if there is something saved
    if $stashed
    then
        _gcvs_echo "Applying stash..."
        git stash pop
    fi

    _gcvs_echo "Repository updated."

    if type gcvs_on_update_complete &> /dev/null
    then
        gcvs_on_update_complete
    fi
)

gcvs_export() (
    set -e

    local branch=`git rev-parse --abbrev-ref HEAD`

    if [[ $branch == "tmp-"* ]]
    then
        _gcvs_echo "Current branch \`$branch\` seems like a temporary branch, \
aborted."
        exit 1
    fi

    local timestamp=`_gcvs_get_var timestamp`

    _gcvs_delete_var timestamp

    local last_commit_message=`git log -1 --pretty=%B`

    if [[ $last_commit_message == "CVS update"* ]]
    then
        _gcvs_echo "Current commit is a CVS update commit, exporting aborted."
        exit 1
    fi

    _gcvs_echo "Stashing changes..."

    if [[ -z $timestamp ]]
    then
        timestamp=`date +%s`

        local stash_result=`git stash save --include-untracked\
            "stash-$timestamp"`

        if [[ $stash_result == *"No local changes to save"* ]]
        then
            _gcvs_echo "No local changes to save."
        fi
    fi

    local branch=`git rev-parse --abbrev-ref HEAD`
    local tmp_branch="tmp-$timestamp"

    _gcvs_set_var branch "$branch"
    _gcvs_set_var message "$last_commit_message"

    _gcvs_echo "Checking out temporary branch \`$tmp_branch\`..."
    git checkout -b "$tmp_branch" HEAD~1

    _gcvs_echo "Exporting commit to CVS..."

    set +e
    git cvsexportcommit -cpu "$branch~1" "$branch"
    local export_status=$?
    set -e

    git add .
    git commit -m "-" || true

    if [[ $export_status -eq 0 ]]
    then
        _gcvs_echo "Commit exported successfully."
        _gcvs_echo "Merging changes back to \`$branch\`..."

        git checkout "$branch"
        git merge --squash "$tmp_branch"
        git commit -m "CVS update during exporting" || true

        _gcvs_echo "Deleting temporary branch..."
        git branch -D "$tmp_branch"

        local stash_index=`git stash list | grep "stash-$timestamp\$" |\
            grep -o --color=never "stash@{[0-9]\+}"`

        if [[ -n $stash_index ]]
        then
            _gcvs_echo "Applying stash..."
            git stash pop "$stash_index"
        fi

        _gcvs_echo "Exporting completed."

        if type gcvs_on_export_complete &> /dev/null
        then
            gcvs_on_export_complete
        fi
    else
        _gcvs_echo "Merging \`$branch\` to temporary branch..."

        set +e
        git merge "$branch" -m "$last_commit_message"
        local merge_status=$?
        set -e

        if [[ $merge_status -eq 0 ]]
        then
            _gcvs_echo "Automatic merging succeed, please review the content \
on this temporary branch, make nacessary changes and execute \
\`gcvs_export_continue\` to export again."
        else
            _gcvs_echo "Automatic merging failed, please resolve conflict \
manually and commit to this temporary branch. Then execute \
\`gcvs_export_continue\` to export again."
        fi

        _gcvs_echo "If the exporting process doesn't seem to be right to you, \
try to checkout your working branch \`$branch\`, fix potential causes and try \
to start the process again."
    fi
)

gcvs_export_continue() (
    set -e

    local branch=${1:-`_gcvs_get_var branch`}

    if [[ -z $branch ]]
    then
        _gcvs_echo "Please specify the working branch, possibly \`master\`?"
        exit 1
    fi

    local tmp_branch=`git rev-parse --abbrev-ref HEAD`

    if [[ $tmp_branch != "tmp-"* ]]
    then
        _gcvs_echo "Current branch \`$tmp_branch\` does not seem like a \
temporary branch, aborted."
        exit 1
    fi

    local status_output=`git status --porcelain`

    if [[ -n `echo "$status_output" | grep -v "^[^? ]"` ]]
    then
        _gcvs_echo "Directory not clean, please stage all the changes."
        exit 1
    fi

    if [[ -n $status_output ]]
    then
        local message=`_gcvs_get_var message`

        if [[ -z $message ]]
        then
            _gcvs_echo "Cannot find commit message, please commit manually \
before continue."
        fi

        _gcvs_echo "Committing changes..."
        git commit -m "$message" || true
    fi

    _gcvs_set_var timestamp `echo "$tmp_branch" | sed s/^tmp-//`

    git checkout "$branch"
    git reset --hard HEAD~1
    git merge "$tmp_branch"

    _gcvs_echo "Deleting temporary branch, will create again later..."
    git branch -D "$tmp_branch"

    gcvs_export
)

gcvs_git_commit_as_cvs_update() (
    set -e
    git commit -m "CVS update"
)

gcvs_update_gitignore() (
    set -e

    local gitignore_path=`_gcvs_repository_dir`/.gitignore

    cat .cvsignore > "$gitignore_path"
    printf '\n\
.#*\n\
.msg\n\
.cvsexportcommit.diff\n\
'\
    >> "$gitignore_path"
)

gcvs_cleanup() (
    find . -type f -name '.#*' -delete -printf "removed %p\n"
    rm -fv .msg
    rm -fv .cvsexportcommit.diff

    local branches=`git branch | grep --color=never "^\s\+tmp-" | xargs`

    if [[ -n $branches ]]
    then
        git branch -D $branches
    fi
)

# _gcvs_get_var "name"
_gcvs_get_var() {
    local var_path=`_gcvs_dot_git_dir`/gcvs/vars/$1

    if [[ -e $var_path ]]
    then
        cat "$var_path"
    fi
}

# _gcvs_set_var "name" "value"
_gcvs_set_var() {
    local gcvs_vars_dir=`_gcvs_dot_git_dir`/gcvs/vars

    mkdir -p "$gcvs_vars_dir"
    echo "$2" > "$gcvs_vars_dir/$1"
}

# _gcvs_delete_var "name"
_gcvs_delete_var() {
    rm -f "`_gcvs_dot_git_dir`/gcvs/vars/$1"
}

_gcvs_repository_dir() {
    echo "`git rev-parse --show-toplevel`"
}

_gcvs_dot_git_dir() {
    echo "`git rev-parse --git-dir`"
}

_gcvs_echo() {
    echo -e "$(tput bold)$1$(tput sgr0)"
}
