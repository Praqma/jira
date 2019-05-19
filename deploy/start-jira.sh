#!/bin/bash

JIRA_VERSION="8.1.0-adoptjre-8u212-v-1.0"
X_PROXY_PORT="8080"
X_PROXY_NAME="jira.praqma.com"
X_PROXY_SCHEME="http"
X_HOST_PORT="8080"

CONTAINER_NAME="jira8adopt-v1"

DPS=$(docker ps -a | grep $CONTAINER_NAME)

if [ ! -z "$DPS" ]; then
  Drunning=$(docker ps --filter "name=$CONTAINER_NAME" | grep $CONTAINER_NAME)
  if [ ! -z "$Drunning" ]; then
    ## Already running
    echo "Its already running..."
  else
    ## Start existing container
    echo "It exists, but is not running."
    echo "Starting container..."
    docker start -a $CONTAINER_NAME
  fi
else
  ## Run new container
  echo "It does not exist, creating container."
  docker run \
    -e X_PROXY_NAME=$X_PROXY_NAME \
    -e X_PROXY_PORT=$X_PROXY_PORT \
    -e X_PROXY_SCHEME=$X_PROXY_SCHEME \
    -p $X_HOST_PORT:8080 \
    --name="$CONTAINER_NAME" \
    -v ${PWD}/jira-plugins.list:/opt/atlassian/jira/jira-plugins.list \
    praqma/jira-server:$JIRA_VERSION
fi
