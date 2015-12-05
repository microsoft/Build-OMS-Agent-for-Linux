#Contributing

### Setup
- Fork the repository recursively to get the submodules:<br>```git clone --recursive git@github.com:MSFTOSSMgmt/bld-omsagent.git```
- If you are contributing in a submodule (dsc, omi, omsagent, opsmgr, pal) chekout the *develop* branch since it is where active development is being made:<br>```git fetch; git checkout develop```
- Use of 'git rebase' is suggested to keep feature branches up to date. To make 'git rebase'
  easier to use, utilize the 'rerere' feature of git. For details on this
  feature, see [rerere documentaiton] (https://git-scm.com/docs/git-rerere) and
  [rebasing documentation] (https://www.git-scm.com/book/en/v2/Git-Branching-Rebasing).
  Issue the following commands to set up the 'rerere' feature in git's global configuration:
```
 git config --global rerere.enabled true
 git config --global rerere.autoUpdate true
```
- From the develop branch, create a feature branch where you will add your contribution.<br>
  By convention, for feature branch names, we use the format ```<username>-<feature_name>```<br>
  ```git checkout -b <branch-name>```

### Code
- Make the changes as needed, test them out
- Commit the changes:
```shell
  git add <changed files>
  git commit -m "commit message"
```
- Push the changes to the server:<br>```git push```

### Review
- On [github](https://github.com/MSFTOSSMgmt/bld-omsagent), create a new pull request.
That page should only show your changes. Be sure there is a relevant subject for the
pull request. In the details, include the line "@MSFTOSSMgmt/omsdevs" and any other
comments relevant for the reviewers.
- If you need to make new changes based on review, you can just update your branch with further commits and ask for additional reviews.
- Reviewers can sign off by leaving a comment on the *conversation* tab of the pull request.

### Merge
Once the pull request is reviewed, it can be merged to the develop branch. While github
itself can perform the merge easily, it uses the --no-ff option (no fast forward), resulting
in somewhat messy git logs. As a result, we do not suggest use of github for merging your
changes. Instead, we recommend use of the command line.

- Merge latest changes to your feature branch from development branch:
```
git checkout develop
git pull
git checkout <branch-name>
git rebase develop
```
<br>Resolve any merge conflicts that may be necessary. If changes are necessary,
be certain to commit them to your feature branch.
- Go to the development branch:<br>```git checkout develop```
- Merge your changes to the development branch:<br>```git merge <branch-name>```
- Push the merge to github:<br>```git push```

### Cleanup
You should clean up your old branches. To do so:
- Delete remote branch:<br>```git push origin --delete <branch-name>```
- Delete local branch:<br>```git branch -d <branch-name>```

### Useful Commands

#### Managing submodules
From the base directory it is easy to manage all the submodule with these commands:

```shell
# Switch to the develop branch
git submodule foreach git checkout develop
# Pull latest changes
git submodule foreach git pull
# Deletes all stale remote-tracking branches
git submodule foreach git remote prune origin
# Show all the branches
git submodule foreach git branch -vv
```
