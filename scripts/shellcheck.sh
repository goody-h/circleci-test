#!/bin/bash

docker run -v "$(pwd)/:/scripts/" --rm koalaman/shellcheck-alpine:stable sh -c 'xargs shellcheck /scripts/*.sh'
