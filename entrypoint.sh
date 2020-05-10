#!/bin/bash
set -e

sudo chown runner:runner .
tar fxz ../runner.tar.gz
sudo rm ../runner.tar.gz

RUNNER_WORKDIR=$HOME/_work
mkdir -p $RUNNER_WORKDIR

[ ! -f auth.json ] && echo "ERROR: No auth config!" && exit 1

case ${GITHUB_AUTH} in
    app)
        [ ! -f auth.pem ] && echo "ERROR: No pem file!" && exit 1
        export RUNNER_TOKEN=$(./Auth/GetRunnerToken --config auth.json) ;;
    token)
        [ -z ${GITHUB_REPOSITORY} ] && echo "ERROR: No repository!" && exit 1
        export RUNNER_TOKEN=$(./Auth/GetRunnerToken --config auth.json --token --repository ${GITHUB_REPOSITORY}) ;;
    *) echo "ERROR: Guru meditation, unknown error" && exit 1 ;;
esac

if [ ! -z "$LABELS" ]; then
    LABELS="--labels $LABELS"
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
    GITHUB_URL=https://github.com/${GITHUB_OWNER}
else
    GITHUB_URL=https://github.com/${GITHUB_REPOSITORY}
fi

./config.sh \
    --name $(hostname) $LABELS \
    --token ${RUNNER_TOKEN} \
    --url ${GITHUB_URL} \
    --work ${RUNNER_WORKDIR} \
    --unattended \
    --replace

echo "$HOME/config.sh remove --unattended --token ${RUNNER_TOKEN}" > $HOME/remove.sh
remove() {
    /bin/sh $HOME/remove.sh
}

trap remove 1 2 3 6 9 11 15
exec ./run.sh "$*"
