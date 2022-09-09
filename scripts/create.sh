#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

"${SCRIPT_DIR}"/deployment_manager.sh create --ref "$CIRCLE_BRANCH" --env "$CIRCLE_ENVIRONMENT"
