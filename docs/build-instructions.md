**Note:** DockerHub is being phased out. Check your builds on [https://cloud.docker.com](https://cloud.docker.com)

# Build this image manually:
```
docker build -t test/jira-server:7.8.0-test .
docker push test/jira-server:7.8.0-test
```

# Automated build at DockerHub / DockerCloud:
Let DockerHub automatically build the image for you based on the tag you set while committing your changes. (This needs your github account and docker account to be linked.) Verify the image creation by logging into dockerhub/docker cloud, and checking list of related docker images.

**Note:** This documents uses lightweight tags, not annotated tags. Though you can use annotated tags too.

## Tag deletion:
### Delete tag - local:
```
git tag  --delete  6.8.2-test
```

#### Delete tag - remote:
```
git push --delete  origin 6.8.2-test
```


## Tag creation:
### Create tag - local:
```
git tag 6.8.2-test
```

### Create tag - remote ( does not push actual code):
```
git push --tags
```


## Order of push-ing tags:
Once changes are committed and ready to be pushed to remote repo, then:
1. always push code first, (this builds :latest on docker hub/cloud)
2. then push the actual tag (this builds the image with the tag, e.g. :6.8.2-test)

```
git push
git push --tags
```



## Example:

```
git add .
git commit -m "some commit message"

TAG='6.8.2-test'
git tag  --delete  ${TAG}
git push --delete  origin  ${TAG}
git tag ${TAG}
git push
git push --tags
```

**Note:** If you you are using annotated tags, you can combine `git push` and `git push --tags` into one command, i.e. `git push --follow-tags`.
 
In case your tag was not pushed with `--follow-tags`, just do it manually:
```
git push --tags 
```

