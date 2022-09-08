#!/bin/bash

docker run -v $(pwd)/deployment_manager.sh:/script.sh --rm koalaman/shellcheck-alpine:stable xargs shellcheck /script.sh