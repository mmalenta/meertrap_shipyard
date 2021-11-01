#!/bin/bash

source ./tag_functions.sh
source ./logging.sh

function help() 
{
  echo "Build a new post-processing Docker image and document the process"
  echo 
  echo "Usage: build_post.sh [OPTIONS]"
  echo
  echo "Available options:"
  echo "-h	print this message"
  echo "-d	dockerfile"
  echo "-b	post-processing branch to use"
  echo "-t	post-processing version tag"
  echo "-f  force the tag"
  echo
  exit 0
}

function print_config()
{
  echo
  INFO "### Build configuration ###"
  echo "Dockerfile: ${dockerfile}"
  echo "Post-processing branch: ${post_branch}"
  echo "Version tag: ${version_tag}"
  if [[ -n $notes ]]
  then
    echo "Notes: ${notes}"
  fi
  echo
}

optstring=":hd:b:t:n:f"
force=false

while getopts ${optstring} arg
do
  case ${arg} in
    h)
      help
      ;;
    d)
      dockerfile=${OPTARG}
      ;;
    b)
      post_branch=${OPTARG}
      ;;
    t)
      version_tag=${OPTARG}
      ;;
    n)
      notes=${OPTARG}
      ;;
    f) 
      force=true
      INFO "Will force build with the provided tag!"
      ;;
    ?)
      ERROR "Invalid option -${OPTARG}"
      help
      exit 2
      ;; 
  esac
done
# Get the latest tag of the post-processing Docker image
# Saved into a global variable $latest_tag
get_latest_tag post-processing

if [[ -z $dockerfile ]]
then
  WARNING "Dockerfile not set. Will use the default one..."
  dockerfile="PostProcessing.docker"
elif [[ ! -e $dockerfile ]]
then
  ERROR "Dockerfile does not exist!"
  exit 1
fi

if [[ -z $post_branch ]]
then
  WARNING "Post-processing branch not set. Will use the default one..."
  post_branch="test"
fi

if [[ -z $version_tag ]]
then
  WARNING "Version tag not set. Will generate one..."
  # Follow PEP440 limited to just beta and stable releases
  # Saved into a global variable $version_tag
  generate_version_tag
else
  check_version_tag $version_tag $force
fi

print_config

docker build -f $dockerfile --no-cache=true --build-arg POST_BRANCH=${post_branch} -t post-processing:${version_tag} . | tee build_log.tmp && echo "$( date ) post-processing:${version_tag} ${post_branch} ${notes}" >> post_proc_builds.dat
