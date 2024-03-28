#!/bin/bash
#
# Description: This will configure an existing instance using ssh protocols.
#
# Installation:
#   Git client
#   Git credentials
#
# Copyright (c) 2022 STY-Holdings Inc
# MIT License
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the “Software”), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to
# do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

set -eo pipefail

# script variables
FILENAME=$(basename "$0")

# Private Variables
ACTION="none"
export IDENTITY          # This is set by calling build-ssh-identity.sh function build_ssh_identity.
export IDENTITY_FILENAME # This is set by calling build-ssh-identity_filename.sh function build_ssh_identity_filename.
WAIT="yes"
DISPLAY_EXPORTS="yes"

function init_script() {
  echo "Remove existing core-devops directory, if any."
  rm -rf core-devops
  echo "Cloning Core DevOps scripts"
  git clone https://github.com/sty-holdings/core-devops
  #  Core
  . core-devops/scripts/0-initialize-core-scripts.sh
  #
  display_spacer
  display_info "Script has been initialized."
}

# shellcheck disable=SC2028
function print_exports() {
  echo "INSTANCE_NUMBER:\t\t$INSTANCE_NUMBER"
  echo "LOCAL_ALIAS_FQN:\t\t$LOCAL_ALIAS_FQN"
  echo "LOCAL_USER_HOME_DIRECTORY:\t$LOCAL_USER_HOME_DIRECTORY"
  echo "SERVER_ENVIRONMENT:\t\t$SERVER_ENVIRONMENT"
  echo "SERVER_INSTANCE_IPV4:\t\t$SERVER_INSTANCE_IPV4"
  echo "SOURCE_ALIAS_FILENAME:\t\t$SOURCE_ALIAS_FILENAME"
  echo "SOURCE_EXPORT_FILENAME:\t\t$SOURCE_EXPORT_FILENAME"
  echo "SOURCE_PROFILE_FILENAME:\t$SOURCE_PROFILE_FILENAME"
  echo "SOURCE_VIMRC_FILENAME:\t\t$SOURCE_VIMRC_FILENAME"
  echo "SYSTEM_USER:\t\t\t$SYSTEM_USER"
  echo "SYSTEM_USER_GROUP:\t\t$SYSTEM_USER_GROUP"
  echo "SYSTEM_USERS_HOME_DIRECTORY:\t$SYSTEM_USERS_HOME_DIRECTORY"
  echo "WORKING_AS:\t\t\t$WORKING_AS   *** IMPORTANT - DOUBLE CHECK THIS VALUE ***"
}

# shellcheck disable=SC2028
function print_usage() {
  display_info "This will configure a virtual machine using ssh protocol."
  echo
  echo "Usage: $FILENAME -h | -I | -y <yaml filename> <action> [-D | -W]"
  echo
  echo "Global flags:"
  echo "  -h\t\t\t display help"
  echo "  -I\t\t\t Prints additional information about $FILENAME."
  echo "  -y <yaml filename>\t The FQN of the yaml file containing all the needed settings."
  echo "  -W\t\t\t Do not wait to review the yaml and export settings."
  echo "  -D\t\t\t Do not display the export and yaml settings."
  echo
  echo "Actions (Listing in order of recommended execution)"
  echo "  -k\t Set up ssh private/public keys on the server for WORKING_AS. (Operator is prompted)"
  echo "  -a\t Adds an alias to connect to the server for WORKING_AS. (Resets shell required)"
  echo "  -U\t Create SYSTEM_USER on the server. (Operator is prompted and resets shell required)"
  echo "  -s\t Adding SYSTEM_USER to sudo group and include file (Skip -S)"
  echo "  -S\t Adding SYSTEM_USER to sudo group and include file with NOPASSWD (Skip -s)"
  echo "  -c\t Configure a SYSTEM_USER on the server with action -c."
  echo
}

function validate_arguments() {
  if [ $ACTION == "none" ]; then
    local Failed="true"
    display_error "You have to provide an action."
  fi
  # shellcheck disable=SC2086
  if [ -z $YAML_FILENAME ]; then
    local Failed="true"
    display_error "You have to provide a YAML filename."
  fi

  if [ "$Failed" == "true" ]; then
    print_usage
    exit 99
  fi
}

function validate_parameters() {
  if [ -z "$LOCAL_ALIAS_FQN" ]; then
    local Failed="true"
    display_error "The local alias filename (FQN) must be provided."
  fi
  if [ -z "$LOCAL_USER_HOME_DIRECTORY" ]; then
    local Failed="true"
    display_error "The local users home directory (FQN) must be provided."
  fi
  validate_server_environment
  # shellcheck disable=SC2154
  if [ "$validate_server_environment_result" == "failed" ]; then
    exit 99
  fi
  if [ -z "$SERVER_INSTANCE_IPV4" ]; then
    local Failed="true"
    display_error "The IPV4 address must be provided."
  fi
  if [ -z "$SOURCE_ALIAS_FILENAME" ]; then
    local Failed="true"
    display_error "The source alias filename parameter is missing from the yaml file."
  fi
  if [ -z "$SOURCE_EXPORT_FILENAME" ]; then
    local Failed="true"
    display_error "The source export filename parameter is missing from the yaml file."
  fi
  if [ -z "$SOURCE_PROFILE_FILENAME" ]; then
    local Failed="true"
    display_error "The source profile filename parameter is missing from the yaml file."
  fi
  if [ -z "$SOURCE_VIMRC_FILENAME" ]; then
    local Failed="true"
    display_error "The source vimrc filename parameter is missing from the yaml file."
  fi
  if [ -z "$SYSTEM_USER" ]; then
    local Failed="true"
    display_error "The SYSTEM_USER must be provided."
  fi
  if [ -z "$SYSTEM_USER_GROUP" ]; then
    local Failed="true"
    display_error "The SYSTEM_USER_GROUP must be provided."
  fi
  if [ -z "$SYSTEM_USERS_HOME_DIRECTORY" ]; then
    local Failed="true"
    display_error "The SYSTEM_USERS_HOME_DIRECTORY (FQN) must be provided."
  fi

  if [ "$Failed" == "true" ]; then
    print_usage
    exit 99
  fi
}

function validate_tool_list() {
  if [ -z "$TOOL_LIST" ]; then
    validate_tool_list_result="failed"
    display_error "The TOOL_LIST parameter is missing from the yaml file."
  fi
}

# Main function of this script
function run_script {
  if [ "$#" == "0" ]; then
    display_error "No parameters where provided."
    print_usage
    exit 99
  fi

  while getopts 'Wy:acDhiIknsSU' OPT; do # see print_usage
    case "$OPT" in
    a)
      ACTION="ALIAS"
      ;;
    c)
      ACTION="CONFIG"
      ;;
    D)
      DISPLAY_EXPORTS="no"
      ;;
    i)
      ACTION="INSTALL"
      ;;
    I)
      display_info "FLAG: -I Print action variables"
      print_additional_info $FILENAME
      display_spacer
      exit 0
      ;;
    k)
      ACTION="KEYS"
      ;;
    n)
      ACTION="HOSTNAME"
      ;;
    s)
      ACTION="SUDO"
      ;;
    S)
      ACTION="SUDO-NOPASSWD"
      ;;
    U)
      ACTION="USER"
      ;;
    W)
      WAIT="no"
      ;;
    y)
      set_variable YAML_FILENAME "$OPTARG"
      ;;
    h)
      print_usage
      exit 0
      ;;
    *)
      display_error "Please review the usage printed below:" >&2
      print_usage
      exit 99
      ;;
    esac
  done

# Setup
#
# Validating inputs to the script
#
  validate_arguments
#
# Pulling configuration from Github
#
  display_info "Remove existing configurations directory, if any."
  rm -rf configurations
  display_info "Cloning Core DevOps scripts"
  git clone https://github.com/sty-holdings/configurations
  display_spacer
  display_info "Configuration is available."
#
# Display yaml settings
#
  display_spacer
  if [ "$DISPLAY_EXPORTS" == "yes" ]; then
    display_info "YAML file values:"
    # shellcheck disable=SC2086
    print_formatted_yaml $YAML_FILENAME
  fi
  display_spacer
#
# Adding yaml setting as exports
#
  get_now_formatted '%Y-%m-%d-%H-%M-%S'
  # shellcheck disable=SC2086
  # shellcheck disable=SC2154
  parse_export_yaml_filename_prefix $YAML_FILENAME $now
  # shellcheck disable=SC2086
  myExports=$(cat /tmp/$now-exports.sh)
  # shellcheck disable=SC2086
  eval $myExports
  rm /tmp/*-exports.sh
  validate_parameters
  if [ "$DISPLAY_EXPORTS" == "yes" ]; then
    display_info "YAML values exported"
    print_exports
    if [ "$WAIT" == "yes" ]; then
      display_info "Waiting 8 seconds to allow review of setting. Ctrl+c to abort."
      sleep 8
      display_spacer
    fi
  fi
  display_spacer
#
# Building ssh identity file for the server user
#
  # shellcheck disable=SC2086
  build_ssh_identity_filename $WORKING_AS $LOCAL_USER_HOME_DIRECTORY $SERVER_ENVIRONMENT $INSTANCE_NUMBER
  # shellcheck disable=SC2086
  build_ssh_identity $IDENTITY_FILENAME
#
# Processing Action
#
  case "$ACTION" in
  ALIAS)
    # Add a local Alias for the instance and user
    display_info "ACTION: -a Adds an alias for the server for the WORKING_AS."
    # shellcheck disable=SC2086
    install_local_instance_alias $WORKING_AS-$SERVER_ENVIRONMENT-$INSTANCE_NUMBER $LOCAL_ALIAS_FQN $WORKING_AS
    display_info "$WORKING_AS will need to refresh the shell or reload it to access the alias."
    display_spacer
    ;;
  CONFIG)
    # Configure the non-root user
    display_info "ACTION: -c Configure SYSTEM_USER on the server."
    # shellcheck disable=SC2086
    build_ssh_identity_filename $SYSTEM_USER $LOCAL_USER_HOME_DIRECTORY $SERVER_ENVIRONMENT $INSTANCE_NUMBER
    # shellcheck disable=SC2086
    build_ssh_identity $IDENTITY_FILENAME
    # shellcheck disable=SC2086
    scp $IDENTITY $SOURCE_ALIAS_FILENAME $SYSTEM_USER@$SERVER_INSTANCE_IPV4:.
    # shellcheck disable=SC2086
    scp $IDENTITY $SOURCE_EXPORT_FILENAME $SYSTEM_USER@$SERVER_INSTANCE_IPV4:.
    # shellcheck disable=SC2086
    scp $IDENTITY $SOURCE_PROFILE_FILENAME $SYSTEM_USER@$SERVER_INSTANCE_IPV4:.
    # shellcheck disable=SC2086
    scp $IDENTITY $SOURCE_VIMRC_FILENAME $SYSTEM_USER@$SERVER_INSTANCE_IPV4:.
    # shellcheck disable=SC2086
    scp $IDENTITY configurations/scripts/config-server-user.sh $SYSTEM_USER@$SERVER_INSTANCE_IPV4:.
    # shellcheck disable=SC2086
    ssh $IDENTITY $SYSTEM_USER@$SERVER_INSTANCE_IPV4 "sh config-server-user.sh"
    display_spacer
    ;;
  HOSTNAME)
    #    Change the hostname
    display_info "ACTION: -n Change the hostname "
    if [ "$WORKING_AS" == "root" ]; then
      hostname=$(echo "$SERVER_INSTANCE_IPV4" | cut -d '.' -f1)
      # shellcheck disable=SC2086
      cp $LOCAL_USER_HOME_DIRECTORY/.ssh/known_hosts $LOCAL_USER_HOME_DIRECTORY/.ssh/known_hosts.original
      # shellcheck disable=SC2029
      # shellcheck disable=SC2086
      ssh $WORKING_AS@$SERVER_INSTANCE_IPV4 "sudo cp /etc/hostname /etc/hostname.orig; sudo echo $hostname > /etc/hostname; sudo shutdown -r now;" || true
      # shellcheck disable=SC2086
      cp $LOCAL_USER_HOME_DIRECTORY/.ssh/known_hosts.original $LOCAL_USER_HOME_DIRECTORY/.ssh/known_hosts
    else
      display_error "WORKING_AS in the yaml file must be set to root to execute this function."
    fi
    display_spacer
    ;;
  INSTALL)
    display_info "ACTION: -i Installing tools such as docker"
    validate_tool_list
    if [ "$validate_tool_list_result" == "failed" ]; then
      exit 99
    fi
    IFS=','
    for tool in "${TOOL_LIST[@]}"; do
      install_tool $tool
    done
    IFS=$' \t\n'
    display_spacer
    ;;
  KEYS)
    # Generate and install ssh identity key
    display_info "ACTION: -k Set up ssh private/public keys on the server for WORKING_AS. (Operator is prompted)"
    display_info "The script is going to install the new ssh key. You will be prompted for the users password on the command line."
    # shellcheck disable=SC2086
    if [ -f $IDENTITY_FILENAME ]; then
      display_spacer
      display_info "$IDENTITY_FILENAME already exists. Existing key will be used."
    else
      display_spacer
      # shellcheck disable=SC2086
      build_private_public_key $IDENTITY_FILENAME
    fi
    # shellcheck disable=SC2086
    ssh-copy-id $IDENTITY -o PubKeyAuthentication=no $WORKING_AS@$SERVER_INSTANCE_IPV4
    rebuild_ssh_add
    display_spacer
    ;;
  SUDO)
    #  Grant user sudo powers
    display_info "ACTION: -s Adding SYSTEM_USER to sudo group and include file"
    if [ "$WORKING_AS" == "root" ]; then
      # shellcheck disable=SC2029
      # shellcheck disable=SC2086
      ssh $IDENTITY $WORKING_AS@$SERVER_INSTANCE_IPV4 "sudo usermod -aG sudo $SYSTEM_USER;"
    else
      display_error "WORKING_AS in the yaml file must be set to root to execute this function."
    fi
    display_spacer
    ;;
  SUDO-NOPASSWD)
    #  Grant user sudo powers without password
    display_info "ACTION: -S Adding SYSTEM_USER to sudo group and include file with NOPASSWD"
    if [ "$WORKING_AS" == "root" ]; then
      # shellcheck disable=SC2029
      # shellcheck disable=SC2086
      ssh $IDENTITY $WORKING_AS@$SERVER_INSTANCE_IPV4 "sudo usermod -aG sudo $SYSTEM_USER;"
      # shellcheck disable=SC2029
      # shellcheck disable=SC2086
      ssh $IDENTITY $WORKING_AS@$SERVER_INSTANCE_IPV4 "sudo echo '$SYSTEM_USER ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$SYSTEM_USER"
    else
      display_error "WORKING_AS in the yaml file must be set to root to execute this function."
    fi
    display_spacer
    ;;
  USER)
    #  Create user on server
    display_info "ACTION: -u Create a SYSTEM_USER. (Operator is prompted)"
    # shellcheck disable=SC2086
    build_ssh_identity_filename $WORKING_AS $LOCAL_USER_HOME_DIRECTORY $SERVER_ENVIRONMENT $INSTANCE_NUMBER
    # shellcheck disable=SC2086
    build_ssh_identity $IDENTITY_FILENAME
    # shellcheck disable=SC2029
    # shellcheck disable=SC2046
    # shellcheck disable=SC2005
    # shellcheck disable=SC2086
    echo $(ssh $IDENTITY $WORKING_AS@$SERVER_INSTANCE_IPV4 "sudo groupadd $SYSTEM_USER_GROUP")
    login_allowed='true'
    # shellcheck disable=SC2086
    install_server_user "$IDENTITY" $WORKING_AS $SERVER_INSTANCE_IPV4 $SYSTEM_USER $SYSTEM_USER_GROUP $login_allowed
    # shellcheck disable=SC2154
    if [ "$install_server_user_result" == "failed" ]; then
      exit 99
    else
      echo "$install_server_user_result"
    fi
    # Add ssh authorized key to user
    # shellcheck disable=SC2086
    build_ssh_identity_filename $SYSTEM_USER $LOCAL_USER_HOME_DIRECTORY $SERVER_ENVIRONMENT $INSTANCE_NUMBER
    # shellcheck disable=SC2086
    build_ssh_identity $IDENTITY_FILENAME
    # shellcheck disable=SC2086
    if [ -f $IDENTITY_FILENAME ]; then
      display_spacer
      display_info "$IDENTITY_FILENAME already exists. Existing key will be used."
    else
      display_spacer
      # shellcheck disable=SC2086
      build_private_public_key $IDENTITY_FILENAME
    fi
    # shellcheck disable=SC2086
    install_local_instance_alias "alias $SYSTEM_USER-$SERVER_ENVIRONMENT-$INSTANCE_NUMBER" $LOCAL_ALIAS_FQN $SYSTEM_USER
    # shellcheck disable=SC2086
    ssh-copy-id $IDENTITY -o PubKeyAuthentication=no $SYSTEM_USER@$SERVER_INSTANCE_IPV4
    rebuild_ssh_add
    display_spacer
    ;;
  esac

  echo Done
}

init_script
run_script "$@"
