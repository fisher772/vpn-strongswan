#!/bin/bash

sed -i '/VERSION:=/ s/=.*//' Makefile

sed -i '/DOCKER_USER:=/ s/=.*//' Makefile

sed -i '/DOCKER_TOKEN:=/ s/=.*//' Makefile

# set VERSION
read -p "Enter value to replace VERSION with: " user_version
if [[ -n "$user_version" ]]; then
  sed -i "s|VERSION:|VERSION:=$user_version|" Makefile
else
  :
fi

# set DOCKER_USER
read -p "Enter value to replace DOCKER_USER with: " user_user
if [[ -n "$user_user" ]]; then
  sed -i "s|DOCKER_USER:|DOCKER_USER:=$user_user|" Makefile
else
  :
fi

# set DOCKER_TOKEN
read -p "Enter value to replace DOCKER_TOKEN with: " user_token
if [[ -n "$user_token" ]]; then
  sed -i "s|DOCKER_TOKEN:|DOCKER_TOKEN:=$user_token|" Makefile
else
  :
fi
