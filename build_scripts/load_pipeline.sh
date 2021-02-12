#!/bin/bash

## Credentials Function
function get_username_password() {
  local creds_name=$1

  # Read UserName
  read -p "$creds_name Username:" ${creds_name}_username
  # Read Password
  echo "$creds_name Password:"
  read -s ${creds_name}_password
}

## Check config repo exist
function check_config_repo_exist() {
  local gocd_username=${1:-""}
  local gocd_password=${2:-""}
  local REPO_ID=${3:-""}
  local gocd_url=${4:-"http://localhost:8153"}

  config_repo_exist=`curl -s -o /dev/null -w "%{http_code}" "${gocd_url}/go/api/admin/config_repos/${REPO_ID}" \
        -u "${gocd_username}:${gocd_password}" \
        -H 'Accept:application/vnd.go.cd.v2+json' \
        -i`
}

## Create config repo
function update_config_repo() {
  local gocd_username=${1:-""}
  local gocd_password=${2:-""}
  local git_username=${3:-""}
  local git_password=${4:-""}
  local git_url=${5:-""}
  local gocd_url=${6:-""}
  local repo_id=${7:-""}

  curl "${gocd_url}/go/api/admin/config_repos/${repo_id}" \
        -u "${gocd_username}:${gocd_password}" \
        -H 'Accept: application/vnd.go.cd.v2+json' \
        -H 'Content-Type: application/json' \
        -H 'If-Match: "e064ca0fe5d8a39602e19666454b8d77"' \
        -X PUT \
        -d "{
              \"id\": \"${repo_id}\",
              \"plugin\": \"yaml.config.plugin\",
              \"material\": {
                \"type\": \"git\",
                \"attributes\": {
                  \"url\": \"${git_url}\",
                  \"username\": \"${git_username}\",
                  \"password\": \"${git_password}\",
                  \"branch\": \"master\",
                  \"auto_update\": \"true\"
                }
              },
              \"configuration\": [
                {
                 \"key\": \"pattern\",
                 \"value\": \"build_scripts\/*.yaml\"
               }
              ]
            }"

}

## Create config repo
function create_config_repo() {
  local gocd_username=${1:-""}
  local gocd_password=${2:-""}
  local git_username=${3:-""}
  local git_password=${4:-""}
  local git_url=${5:-""}
  local gocd_url=${6:-""}
  local repo_id=${7:-""}

  curl "${gocd_url}/go/api/admin/config_repos" \
    -u "${gocd_username}:${gocd_password}" \
    -H 'Accept:application/vnd.go.cd.v2+json' \
    -H 'Content-Type:application/json' \
    -X POST -d "{
      \"id\": \"${repo_id}\",
      \"plugin_id\": \"yaml.config.plugin\",
      \"material\": {
        \"type\": \"git\",
        \"attributes\": {
          \"url\": \"${git_url}\",
          \"username\": \"${git_username}\",
          \"password\": \"${git_password}\",
          \"branch\": \"master\",
          \"auto_update\": \"true\"
        }
      },
      \"configuration\": [
        {
         \"key\": \"pattern\",
        \"value\": \"build_scripts\/*.yaml\"
       }
      ]
    }"

}

#################### main #######################
# Decaler default
GITHUB_username=''
GITHUB_passowrd=''
GOCD_username=''
GOCD_passowrd=''
REPO_HTTPS_URL=''
REPO_ID=''
GOCD_URL=''


## Check is the current folder part of a git repo.
if ! [ -f "../.git/config" ]; then
    echo "The current $(pwd) folder is not within a git repo"
    exit 1
fi

## Check that git,curl,sed,cut are availabe on the current os
for i in `echo git curl sed cut`;
do
  which $i > /dev/null || echo "$i binary is not available please install $i before continue"
done

## Get repo url
REPO_URL=$(git config --get remote.origin.url)

## Check repo url and convert to https if needed
if [[ $REPO_URL =~ "@" ]]; then
   REPO_HTTPS_URL=https://$(echo $REPO_URL | cut -d "@" -f 2 | sed 's/:/\//')
else
  $REPO_HTTPS_URL=$REPO_URL
fi

## Get repo id
read -p "GoCD config repo id: " REPO_ID
if [ -z "$REPO_ID" ]; then
  REPO_ID=$(basename `git rev-parse --show-toplevel`)
  echo "Repo_id was not given using git repo folder name: ${REPO_ID}"
fi

## Get Gocd url
read -p "GoCd url:" gocd_url
if [ -z "$GOCD_URL" ]; then
  GOCD_URL="http://localhost:8153"
  echo "Gocd_url was not given using default: ${GOCD_URL} instead"
fi

## Get github creds
get_username_password GITHUB
## Get GoCD creds
get_username_password GOCD

# Check config repo exist in GoCD
check_config_repo_exist $GOCD_username $GOCD_password $REPO_ID $GOCD_URL
if [[ $config_repo_exist == 200 ]]; then
  read -p "The ${REPO_ID} config repo already exist in GoCD do you which to update it (y/n)" update_config_repo
  if [[ $update_config_repo == y ]]; then
      echo "Updating ${REPO_ID} config repo configuration"
      update_config_repo "$GOCD_username" "$GOCD_password" "$GITHUB_username" "$GITHUB_password" "$REPO_HTTPS_URL" "$GOCD_URL" "$REPO_ID"
  fi
else
  echo "Creating ${REPO_ID} config repo configuration"
  create_config_repo "$GOCD_username" "$GOCD_password" "$GITHUB_username" "$GITHUB_password" "$REPO_HTTPS_URL" "$GOCD_URL" "$REPO_ID"
fi
