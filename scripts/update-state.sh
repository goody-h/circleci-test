#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

"${SCRIPT_DIR}"/deployment_manager.sh status "$PARAM_DEPLOYMENT_ID" "$PARAM_STATE"
