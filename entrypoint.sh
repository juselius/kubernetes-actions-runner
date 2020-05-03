#!/bin/bash
set -e

registration_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/registration-token"
echo "Requesting registration URL at '${registration_url}'"

payload=$(curl -sX POST -H "Authorization: token ${GITHUB_TOKEN}" ${registration_url})
export RUNNER_TOKEN=$(echo $payload | jq .token --raw-output)

sudo chown runner:runner .
tar fxz ../runner.tgz
sudo rm ../runner.tgz

RUNNER_WORKDIR=$HOME/_work
mkdir -p $RUNNER_WORKDIR

if [ ! -z "$LABELS" ]; then
    LABELS="--labels $LABELS"
fi
./config.sh \
    --name $(hostname) $LABELS \
    --token ${RUNNER_TOKEN} \
    --url https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY} \
    --work ${RUNNER_WORKDIR} \
    --unattended \
    --replace

echo "$HOME/config.sh remove --unattended --token ${RUNNER_TOKEN}" > $HOME/remove.sh
remove() {
    /bin/sh $HOME/remove.sh
}

trap remove 1 2 3 6 9 11 15
exec ./run.sh "$*"
