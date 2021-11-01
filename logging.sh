#!/bin/bash

INF="\033[1m"
WRN="\033[1;33m"
ERR="\033[1;31m"
RST="\033[0m"

function WARNING()
{
  local message=$1
  echo -e "${WRN}${message}${RST}"
}

function ERROR()
{
  local message=$1
  echo -e "${ERR}${message}${RST}"
}

function INFO()
{
  local message=$1
  echo -e "${INF}${message}${RST}"
}