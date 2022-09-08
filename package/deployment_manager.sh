#!/bin/bash

# ENV variables
CIRCLE_PROJECT_USERNAME="goody-h"
CIRCLE_PROJECT_REPONAME="ysf-api"
CIRCLE_BRANCH="master"
GH_DEPLOY_APP_PEM=$( cat ./cxepi-github-deployment-manager.2022-08-25.private-key.pem )

# Config
GITHUB_APP_ID="235300" # your github app id
APP_INSTALLATION_ID="28954510" # your app installation id

# variables
GITHUB_API="https://api.github.com"

get_app_token() {
  echo "$GH_DEPLOY_APP_PEM" > ./temp.pem
  PEM="./temp.pem"

  NOW=$( date +%s )
  IAT=$((NOW - 10))
  EXP=$((NOW + 600))
  HEADER_RAW='{"alg":"RS256"}'
  HEADER=$( echo "${HEADER_RAW}" | tr -d '\n' | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n' )
  PAYLOAD_RAW='{"iat":'"${IAT}"',"exp":'"${EXP}"',"iss":"'"${GITHUB_APP_ID}"'"}'
  PAYLOAD=$( echo "${PAYLOAD_RAW}" | tr -d '\n' | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n' )
  HEADER_PAYLOAD="${HEADER}"."${PAYLOAD}"
  SIGNATURE=$( echo "${HEADER_PAYLOAD}" | tr -d '\n' | openssl dgst -sha256 -sign ${PEM} | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n' )
  JWT="${HEADER_PAYLOAD}"."${SIGNATURE}"

  APP_TOKEN_STRING=$(
    curl \
    -s \
    -X POST \
    -H "Accept: application/vnd.github.machine-man-preview+json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${JWT}" \
    "${GITHUB_API}/app/installations/${APP_INSTALLATION_ID}/access_tokens" \
    | tr -d '\n' \
    | sed -E 's/^.*\"token\" *: *"([^"]+)".*$/\1/g'
  )

  rm $PEM
  echo "$APP_TOKEN_STRING"
}

get_repo_fullname() {
  if [[ -z $CIRCLE_PROJECT_USERNAME ]] || [[ -z $CIRCLE_PROJECT_REPONAME ]]
    then 
      echo "Error! One or more environment variables are missing; can't determine org or repository name"
      exit 255
    else
      echo "${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
    fi
}

create() {
  if [[ -z $REF ]]
    then
      REF=${CIRCLE_BRANCH}
    fi

  if [[ -z $ENV ]]
    then
      ENV="dev"
    fi

  DEPLOYMENT=$(
    curl \
    -s \
    -X POST \
    -H "Accept: application/vnd.github.machine-man-preview+json" \
    -H "Content-Type: application/json" \
    -H "Authorization: token  $(get_app_token)" \
    -d '{"ref": "'${REF}'", "environment": "'${ENV}'", "auto_merge": false}' \
    "${GITHUB_API}/repos/$(get_repo_fullname)/deployments"
  )

  echo "$DEPLOYMENT"
}

status() {
  ID=${POSITIONAL_ARGS[1]}
  if [[ -z $ID ]]
    then
      echo "Error: Missing argument 'ID'."
      exit 255
    fi

  STATE=${POSITIONAL_ARGS[2]}
  if [[ -z $STATE ]]
    then
      echo "Error: Missing argument 'STATE'."
      exit 255
    fi

  STATUS_UPDATE=$(
    curl \
    -s \
    -X POST \
    -H "Accept: application/vnd.github.machine-man-preview+json" \
    -H "Authorization: token  $(get_app_token)" \
    -H "Content-Type: application/json" \
    -d '{"state": "'"${STATE}"'"}' \
    "${GITHUB_API}/repos/$(get_repo_fullname)/deployments/${ID}/statuses"
  )

  echo "$STATUS_UPDATE"
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --ref)
      REF="$2"
      shift # past argument
      shift # past value
      ;;
    --environment|--env)
      ENV="$2"
      shift # past argument
      shift # past value
      ;;
    -*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

case ${POSITIONAL_ARGS[0]} in
  create)
    create
    ;;

  status)
    status
    ;;

  *)
    echo "unknown command"
    exit 255
    ;;
esac
