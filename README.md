# GitHub Actions Runner for Kubernetes

Self-hosted Actions runner to be deployed in Kubernetes. Uses `dind`
(Docker-in-Docker) to run containerized actions in a container.

### Usage

```
deploy-actions-runner -n namespace -o owner -t token [-r repo] [ -p packages token ] | kubectl apply -f -

```


