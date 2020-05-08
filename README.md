# GitHub Actions Runner for Kubernetes

Self-hosted GitHub Actions runner for deployment in Kubernetes. The runner can
also be run locally, connected directly to the host docker daemon.

## Prerequisites

1. The runner automatically requests runner tokens via the GitHub APIs.
   You must create and supply a GitHub Personal Access Token (PAT) with repo
   access permissons to the runner.
2. For Kubernets, `kubectl` must be configured to access the appropriate cluster
   context (in ~/.kube/config)

## TL;DR

```
deploy-actions-runner -o juselius -r inf-3910-webapp -t {PAT} --local
```

```
usage: deploy-actions-runner -o owner -t token [-r repo]
       [--local] [--kubernetes] [-n namespace] [ -p packages token ]
```

### Authentication

The project includes a small tool to get runner tokens from GitHub. It can
authenticate either using PATs or as a GitHub App. In App mode, it can be used
to start organization wide runners.

### Build

The provided Dockerfile will build a docker image with the authentication tool
and actions runnner installed.

#### Plain runner

To build a minimal Docker image, with just the runner and authentication tool:

```
docker build -t actions-runner:latest --target runner .
```

#### Runner with .NET Core 3.1, Node 12, yarn and headless Chrome

To build a runner image for use with the F# SAFE-Template for web
development:

```
docker build -t actions-runner-safe:latest .
```

### Motivation

The self hosted GitHub Actions runner is designed to run in a VM or directly on
a host OS. In order to run on on Kubernetes we must containerize the runner. In
itself, this is pretty simple. But complications arise when we want to support
runnering containers on the runner. This is necessary for two reasons: 1) Many
Marketplace actions run in containers 2) consistent build environments using
containers.

This project tries to hide most of the complications, but still
requires a bit of systems knowledge, and some basic Kubernetes skills.

The project also makes it easy to run GitHub Actions in a container locally.

### Implementation

Running containers in a container can be achieved using Docker-in-Docker (dind).
However, this is complicated by the the need to share volumes from within the
"parent" container. The dind instance is running on top of a local dockerd,
which knows nothing of the interal structure inside the container. A "child"
continer started within a container, is actually not a child, but a sibling.
Both containers run side by side on the same system level `dockerd`. Thus, in
order to share volumes, the volume must be created and shared at the systems
level. This complicated things somewhat.

Another complication is that the action runner runs with UID 1000, but any
containers it starts, might run as root. This can easily mess up file
permissions on shared volumes, so please make sure to reset permissions before
exit.

#### Kubernetes

The Kubernetes deployment relies on `kubectl` being configured correctly on the
executing system. The provided YAML objects are customized using a Kustomization
object.

The Deployment object uses Kubernetes lifecycle management with a preStop hook
to cleanly remove runners.

##### Secrets

The deployment needs a GitHub PAT to generate runner tokens on the fly, whenever
a pod is restarted.  If you want to use GitHub packages from Kubernetes, you
should supply a PAT for accessing Packages. The setup will creates the
appropriate Kubernetes secrets from the tokens automatically.

##### Deployment in Kubernetes

If you want to deploy to a local Kubernetes instance from the Action Runner,
you can use the following recipe, using Helm:

```yaml
deploy-staging:
  container: dtzar/helm-kubectl:latest
  runs-on: self-hosted
  needs: release
  env:
    KUBE_INSTANCE: cluster1
    KUBE_NAMESPACE: default
    DEPLOY_NAME: myapp
  steps:
  - uses: actions/checkout@v2
  - name: Deploy
    run: |
      mkdir -p $HOME/.kube
      echo "${{ secrets.KUBE_CONFIG }}" | base64 -d > $HOME/.kube/config
      kubectl config use-context $KUBE_INSTANCE
      kubectl get pods -n $KUBE_NAMESPACE
      helm list -n $KUBE_NAMESPACE
      cmd=upgrade && helm list -q -n $KUBE_NAMESPACE | grep -q "$DEPLOY_NAME" || cmd=install
      echo "helm $cmd $DEPLOY_NAME"
      helm $cmd -f ./charts/values.yaml \
          --namespace $KUBE_NAMESPACE \
          $DEPLOY_NAME ./charts
  - name: Cleanup
    run: |
      chown -R 1000:1000 .
```

##### Security

The Kubernetes Deployment runs a `dind` side-car container in privileged mode,
to support running docker commands and containerized actions in a container.
*This has security implications, which should be considered and understood
before use!*

#### Local

The runners can easily be run locally on any host with runing `dockerd`. Please
note that you might have to pass in an environment variable `HOST_DOCKER_GID`
with the GID of the docker socket, in order to have access permissions within
the container.

### TODO

* Organization level runners
