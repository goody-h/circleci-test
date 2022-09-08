#!/bin/bash

./deployment_manager.sh create --ref "$CIRCLE_BRANCH" --env "$CIRCLE_ENVIRONMENT"
