#Contributing

### Setup
- Fork the repository recursively to get the submodules:<br>```git clone --recursive git@github.com:MSFTOSSMgmt/bld-omsagent.git```
- If you are contributing in a submodule (dsc, omi, omsagent, opsmgr, pal) chekout the *develop* branch since it is where active development is being made:<br>```git fetch; git checkout develop```
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
- On [github](https://github.com/MSFTOSSMgmt/bld-omsagent), create a new pull request. That page should only show your changes. Be sure there is a relevant subject for the pull request. In the details, include the line "@MSFTOSSMgmt/omsdevs" and any other comments relevant for the reviewers.
- If you need to make new changes based on review, you can just update your branch with further commits and ask for additional reviews.
- Reviewers can sign off by leaving a comment on the *conversation* tab of the pull request.

Merge

Merges can be done two ways:
 1. (Existing way via command line)
 2. (Via the github WWW site)


### Merge
Once the pull request is reviewed, it can be merged to the develop branch.
Here are two ways to merge:

#### 1. Command line
- Go to the development branch:<br>```git checkout develop```
- Merge your changes to the development branch:<br>```git merge <branch-name>```
- Push the merge to github:<br>```git push```

#### 2. Github web interface
- On the pull request page click *merge pull request*
- Confirm you want to merge
- Delete the feature branch

Once the merged changes are pushed to the server, the pull request on github will be automatically closed.

### Cleanup
You should clean up your old branches. To do so:
- Delete remote branch:<br>```git push origin --delete <branch-name>```
- Delete local branch:<br>```git branch -d <branch-name>```
