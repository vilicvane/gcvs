# Git-CVS Workflow Utilities

This is a small set of Git-CVS workflow utilities.

It is expected to initialize and work with a Git repository that shares the
same directory as the CVS repository.

## Disclaimer

Use it at your own risk.

## Install

```sh
git clone https://github.com/vilic/gcvs.git
source gcvs/utilities.sh
```

## Workflow

All the following commands are expected to be executed under CVS working
directory.

> Please check out the source code to see what exactly happens.

### Initialize reporsitory

```sh
gcvs_init
```

### Update reporsitory

```sh
gcvs_update
# alias `gcup`
```

### Export last commit

Please note it will only export the last commit, and it will commit
automatically if export patch applies.

```sh
gcvs_export
# alias `gcxp`
```

### Continue export last commit after resolving conflict

```sh
gcvs_export_continue
# alias `gcxpc`
```

### Git commit as "CVS Update"

Do Git commit with message `"CVS Update (...)"` (commit with message in this
formmat will abort exporting). You may need to do so when your repository gets
messy and need to by synchronized manually.

```sh
gcvs_git_commit_as_cvs_update
# alias `gccu`
```

After Git committing, you may also need to manually commit to CVS as well.

### Update `.gitignore` file

The `.gitignore` file will be updated automatically on intializing and
updating, but you can still manually update it with following command:

```sh
gcvs_update_gitignore
# alias `gcui`
```

### Clean up

Remove `.#*`, `.msg` and `.cvsexportcommit.diff` files.

```sh
gcvs_cleanup
# alias `gccl`
```

### When things got messy

When things got messy, you may need to handle them yourself:

1. Check out your working branch, fix contents and execute `cvsup` manually.
2. Make sure no modification is made regarding to CVS (If there is any, revert
   it or commit them using CVS).
3. Stage every change to Git repository, then execute
   `gcvs_git_commit_as_cvs_update` to commit.

# License

MIT License.
