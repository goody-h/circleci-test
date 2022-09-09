#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

docker run -v "${SCRIPT_DIR}/:/scripts/" --rm koalaman/shellcheck-alpine:stable sh -c 'xargs shellcheck /scripts/*.sh'
