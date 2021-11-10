#!/bin/bash

source ./tag_functions.sh
source ./logging.sh

function help() 
{
  echo "Build new pipeline Docker image and document the process"
  echo 
  echo "Usage: build_pipeline.sh [OPTIONS]"
  echo
  echo "Available options:"
  echo "-h	print this message"
  echo "-d	dockerfile"
  echo "-c	Cheetah branch to use"
  echo "-a	AstroAccelerate branch to use"
  echo "-t	pipeline version tag"
  echo "-n  build notes"
  echo "-f  force the tag"
  echo
  exit 0
}

function print_config()
{
  echo
  INFO "### Build configuration ###"
  echo "Dockerfile: ${dockerfile}"
  echo "Cheetah branch: ${cheetah_branch}"
  echo "AstroAccelerate branch: ${aa_branch}"
  echo "Version tag: ${version_tag}"
  if [[ -n $notes ]]
  then
    echo "Notes: ${notes}"
  fi
  echo
}

function store_build_info()
{
  local repos=("spead2" "psrdada" "astro-accelerate" "panda" "cheetah" "psrdada_cpp" "mkrecv")

  local build_info="$( date ),full-pipeline:${version_tag},${aa_branch},${cheetah_branch}"

  for repo in ${repos[@]}
  do
    clone_line=$( grep -n "Cloning into '${repo}'" build_log.tmp | awk -F ':' '{print $1}' )

    if [ ! -z $clone_line ]
    then
      # There are leftover escape characters
      commit_sha=$( tail -n +${clone_line} build_log.tmp | grep -m 1 -E "^commit|0mcommit" | awk -F ' ' '{print $2}' )
      INFO "Found ${repo} git SHA: ${commit_sha}"
      build_info="${build_info},${commit_sha}"

    else
      WARNING "Did not find ${repo} git SHA!"
      build_info="${build_info},"
    fi

  done

  build_info="${build_info},\"${notes}\""
  echo "Saving build information..."
  echo $build_info >> pipeline_builds.dat
}

optstring=":hd:c:a:t:n:f"
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
    c)
      cheetah_branch=${OPTARG}
      ;;
    a)
      aa_branch=${OPTARG}
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
# Get the latest tag of the pipeline Docker image
# Saved into a global variable $latest_tag
get_latest_tag full-pipeline

if [[ -z $dockerfile ]]
then
  WARNING "Dockerfile not set. Will use the default one..."
  dockerfile="FullPipeline.docker"
elif [[ ! -e $dockerfile ]]
then
  ERROR "Dockerfile does not exist!"
  exit 1
fi

if [[ -z $cheetah_branch ]]
then
  WARNING "Cheetah branch not set. Will use the default one..."
  cheetah_branch="dev"
fi

if [[ -z $aa_branch ]]
then
  WARNING "AA branch not set. Will use the default one..."
  aa_branch="mm_meertrap_test"
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

docker build -f $dockerfile --no-cache=true --build-arg AA_BRANCH=${aa_branch} --build-arg CHEETAH_BRANCH=${cheetah_branch} -t full-pipeline:${version_tag} . | tee build_log.tmp && store_build_info

echo 