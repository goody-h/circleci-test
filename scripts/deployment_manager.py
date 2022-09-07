import dotenv

dotenv.load_dotenv()

from github import Github
from cryptography.hazmat.backends import default_backend
import base64
import click
import jwt
import os
import requests
import sys
import time

# TODO: Refactor with a proper Python class :)
# TODO: This lacks any error checking.

# APP_ID = 188413
APP_ID = 235300
# APP_INSTALLATION_ID = 24768077 
APP_INSTALLATION_ID = 28954510

# Refs
# https://gist.github.com/pelson/47c0c89a3522ed8da5cc305afc2562b0

# This method authenticates to a specific GitHub App installation
# using the app's private key, and generates a time-bound
# access token which can then be used to hit the API
def get_app_token():

    # Get hold of the private key contents

    # When using a file...
    # keystring = open("cx-cloud-ui-github-deployments.2022-04-07.private-key.pem", "r").read()
    # When pulling in from env var with the pem base64 encoded...
    # take the file name and base64 encode it:
    #    cat filename.pem | base64
    # take the encoded output and copy it to your clipboard
    # Set an environment variable like:
    #       export GH_DEPLOY_APP_PEM="<paste>"
    # (make sure to put double quotes around it)

    try:
        keystring = open("cxepi-github-deployment-manager.2022-08-25.private-key.pem", "r").read()
        #keystring = os.environ.get("GH_DEPLOY_APP_PEM")
    except KeyError:
        print("Error! The GitHub App PEM file which has access to modify deployments must be stored")
        print("in an environment variable called GH_DEPLOY_APP_PEM.\n")
        raise
    
    #keystring_decoded_bytes = base64.b64decode(keystring)
    keystring_decoded_bytes = keystring.encode()
    
    private_key = default_backend().load_pem_private_key(keystring_decoded_bytes, None)

    time_since_epoch_in_seconds = int(time.time())

    payload = {
        # get time, issued 10 seconds ago to account for drift
        "iat": time_since_epoch_in_seconds - 10,
        # JWT expiration time (10 minute maximum)
        "exp": time_since_epoch_in_seconds + (10 * 60),
        # GitHub App Identifier
        "iss": "235300",
    }

    print(payload)

    actual_jwt = jwt.encode(payload, private_key, algorithm="RS256")

    print(actual_jwt)

    headers = {
        "Authorization": "Bearer {}".format(actual_jwt),
        "Accept": "application/vnd.github.machine-man-preview+json",
    }

    # # this gets the list of installations for a specific app
    # resp = requests.get("https://api.github.com/app/installations", headers=headers)

    # print("Code: ", resp.status_code)
    # print("Content: ", resp.content.decode())

    resp = requests.post(
        "https://api.github.com/app/installations/{}/access_tokens".format(
            APP_INSTALLATION_ID
        ),
        headers=headers,
    )
    # print("Code: ", resp.status_code)
    # print("Content: ", resp.content.decode())
    token_object = resp.json()
    print(token_object)

    app_token_string = token_object["token"]

    return app_token_string

# TODO: There is a bug where if these re not included, it errors out uncleanly?
#       The KeyError trap does not seem to be working.
def get_repo_fullname():
    try:
        cciproject = os.environ["CIRCLE_PROJECT_USERNAME"]
        ccirepo = os.environ["CIRCLE_PROJECT_REPONAME"]
    except KeyError:
        print("Error! One or more environment variables are missing; can't determine org or repository name.\n")
        raise
    return cciproject + "/" + ccirepo


@click.group() 
def deployment_manager():
    """GitHub Deployment Manager

    This tool helps simplify updating GitHub Deployment statuses when calling pipelines from CircleCI.

    In particular, it infers certain built-in CircleCI environment variables to identify the repo, URLs, etc,
    and elevates them into the GitHub Deployments feature for a specific repository.

    For more information, see: https://docs.github.com/en/actions/deployment/managing-your-deployments/viewing-deployment-history"""
    print("GitHub Deployment Manager\n")


@deployment_manager.command()
@click.argument("id", required=True, type=int)
@click.argument("state", required=True, type=str)
def status(id, state):
    """For a given GitHub Deployment ID, update its status to the given STATE.

    For more information, see https://docs.github.com/en/rest/deployments/statuses."""

    app_token = get_app_token()
    g = Github(app_token)

    repo_fullname = get_repo_fullname()
    repo = g.get_repo(repo_fullname)

    deployment = repo.get_deployment(id)
    status = deployment.create_status(state=state)

    print(deployment)
    print(status)

    return 0


# TODO: if circle branch is missing, this fails. need better error checking or validation.

@deployment_manager.command()
@click.option(
    "ref",
    "--ref",
    default=lambda: os.environ.get("CIRCLE_BRANCH"),
    show_default="Environment variable CIRCLE_BRANCH",
)
@click.option("--environment", "--env", type=str, default="dev")
def create(ref, environment):
    """Creates a new deployment."""

    app_token = get_app_token()
    g = Github(app_token)

    repo_fullname = get_repo_fullname()
    repo = g.get_repo(repo_fullname)

    deployment = repo.create_deployment(
        ref=ref, environment=environment, auto_merge=False
    )

    print(deployment)

    return 0

if __name__ == "__main__":
    sys.exit(deployment_manager())
