function get_latest_tag() 
{
  # Check for the latest tag
  # This assumes we stick to the convention and don't create
  # any tags that deviate from it significantly
  local tag_image=$1
  latest_tag=$( docker image ls ${tag_image} --format {{.Tag}} | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -rn | head -n 1 )
}

function check_version_tag()
{

  # Make sure that there are these components only
  # Strip any text other than 'b' for micro release,
  # which is used for marking beta candidates.

  # Use regexp to check the tag

  local new_tag=$1
  local force_tag=$2

  if [[ $new_tag =~ $BETA_REG ]]
  then
    echo
  elif [[ $new_tag =~ $STABLE_REG ]]
  then
    echo
  else
    echo -e "\033[1;31mNon-conforming tag provided!\033[0m"

    echo "Tags have to adhere to the following convention:"
    echo "Stable release 0.[minor].[micro]"
    echo "Beta release 0.[minor].[micro]b[beta]"
    echo 
    exit 1
  fi

  local head_tag=$( echo $new_tag $latest_tag | tr " " "\n" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -rn | head -n 1 )
  
  if [[ $new_tag == $latest_tag || $head_tag != $new_tag ]]
  then

    # Need to handle beta - > stable release move properly
    # 0.1.8b1 is higher on the sorted list than 0.1.8
    # but from the release sense 0.1.8 is higher
    if [[ $latest_tag =~ $BETA_REG ]]
    then
      if [[ $new_tag == $( echo $latest_tag | sed 's/\(.*\)b[0-9]/\1/g') ]]
      then
        echo "Provided tag moves from beta to the stable release"
        echo -e "\033[1mRequested release tag change:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;32m${new_tag}\033[0m"
      else
        echo -e "\033[1;31mProvided tag does not increment the beta release\033[0m"
        echo -e "\033[1mRequested release tag change:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;31m${new_tag}\033[0m"
        echo

        if [[ $force_tag == true ]]
        then
          echo -e "\033[1;33mWill force the use of the provided tag!\033[0m"
        else
          exit 1
        fi
      fi
    else
      echo -e "\033[1;31mProvided tag does not increment the release\033[0m"
      echo -e "\033[1mRequested release tag change:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;31m${new_tag}\033[0m"
      echo
      if [[ $force_tag == true ]]
      then
        echo -e "\033[1;33mWill force the use of the provided tag!\033[0m"
      else
        exit 1
      fi
    fi
  else
    echo "Provided tag increments the release"
    echo -e "\033[1mRequested release tag change:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;32m${new_tag}\033[0m"
  fi

  if [[ $major -gt 0 ]]
  then
    echo -e "Are you \033[1mreally\033[0m sure we are ready for a release version?"
  fi

}

function generate_version_tag()
{
  local local_tag

  echo

  if [[ $latest_tag =~ $BETA_REG ]]
  then
    echo -e "Latest beta version detected: \033[0m \033[1;33m${latest_tag}\033[0m"
    read -p "Would you like to move to a [s]table release or [i]crement the beta release? " release_choice

    case $release_choice in
      s)
        local_tag=$( echo $latest_tag | sed 's/\(.*\)b[0-9]/\1/g')
        echo -e  "\033[1mMoving to a stable release tag:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;32m${local_tag}\033[0m"
        ;;
      i)
        local beta_version=$(( $(echo $latest_tag | sed 's/.*b\([0-9]*\)/\1/g' ) + 1 ))
        local_tag=$( echo $latest_tag | sed 's/\(.*b\)[0-9]/\1/g')${beta_version}
        echo -e  "\033[1mIncrementing the beta release tag:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;32m${local_tag}\033[0m"
        ;;
      *)
        echo -e "\033[1;31mInvalid option\033[0m"
        exit 1
        ;;
    esac

  elif [[ $latest_tag =~ $STABLE_REG ]]
  then 
    echo -e "Latest stable version detected: \033[0m \033[1;33m${latest_tag}\033[0m"
    read -p "Would you like to increment mi[n]or or mi[c]ro release " release_choice

    case $release_choice in
      n)
        local minor=$(( $( echo $latest_tag | awk -F '.' '{print $2}' ) + 1 ))
        # Assumes we will not reach a major release for a while
        local_tag="0.${minor}.0"
        echo -e  "\033[1mIncrementing the major release tag:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;32m${local_tag}\033[0m"
        ;;
      c)
        local micro=$(( $( echo $latest_tag | awk -F '.' '{print $3}' ) + 1 ))

        if [[ $micro -eq 20 ]]
        then
          echo -e "\033[1;33mMaximum micro version reached!\033[0m"
          echo -e "\033[1;33mWill increment the minor version!\033[0m"
          local minor=$(( $( echo $latest_tag | awk -F '.' '{print $2}' ) + 1 ))
          local_tag="0.${minor}.0"
          echo -e  "\033[1mIncrementing the minor release tag:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;32m${local_tag}\033[0m"
        else
          local_tag=$( echo $latest_tag | sed -r 's/(^[0-9]+.[0-9]+.).*$/\1/g' )${micro}
          echo -e  "\033[1mIncrementing the micro release tag:\033[0m \033[1;33m${latest_tag}\033[0m -> \033[1;32m${local_tag}\033[0m"
        fi
        ;;
      *)
        echo -e "\033[1;31mInvalid option\033[0m"
        echo
        exit 1
        ;;
    esac

  else
    if [[ -z $latest_tag ]]
    then
      echo -e "\033[1;31mDid not find the pipeline image at all\033[0m"
      echo
      exit 1
    else
      echo -e "\033[1;31mLatest image tag not recognised\033[0m"
      echo
      exit 1
    fi
  fi

  version_tag=$local_tag
}