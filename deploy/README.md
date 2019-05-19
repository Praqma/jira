# Deploy Jira stack to Kubernetes from your machine

## Prerequisites

- You need to have a Kubernetes cluster with sufficient resources to run Jira.
- [Install Helm client](https://helm.sh/docs/using_helm/#install-helm)
- Install [helm diff](https://github.com/databus23/helm-diff) `helm plugin install https://github.com/databus23/helm-diff --version master`
- Install [Helmsman](https://github.com/Praqma/helmsman) :
```
# on Linux
curl -L https://github.com/Praqma/helmsman/releases/download/v1.9.1/helmsman_1.9.1_linux_amd64.tar.gz | tar zx
# on MacOS
curl -L https://github.com/Praqma/helmsman/releases/download/v1.9.1/helmsman_1.9.1_darwin_amd64.tar.gz | tar zx

mv helmsman /usr/local/bin/helmsman
```

- TODO: CREATE NECESSARY VOLUMES

## Deploy

```
helmsman --apply -f helmsman-dsf.yaml 
```