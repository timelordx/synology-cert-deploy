#!/usr/bin/env bash
#
# MIT License
#
# Copyright (c) 2023 timelordx
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

## ABOUT
##
## Example of a synology-helper script. Modify it to match your requirements.
##
## This example finds a directory with the most recent files matching your 
## search criteria and sets two environemnt variables: SYNO_HELPER_KEY and
## SYNO_HELPER_FULLCHAIN, poiting to your latest private key and fullChain,
## respectively. These variables can then be used by synology-cert-deploy.sh
## 
## USAGE
## 
## As root, run the helper script first followed by synology-cert-deploy.sh:
##
##   source synology-helper-example.sh
##   synology-cert-deploy.sh
##
## Or as sudo:
##
##   sudo bash -c 'source synology-helper-example.sh; synology-cert-deploy.sh'
##

## ShellCheck verified: https://www.shellcheck.net/
# shellcheck disable=SC2145

##############################################################################
## SCRIPT CONFIG
##############################################################################

## Define search filter and search location of the file you want to find on your Synology
## search filter can contain wildcard / globbing characters: * ? []
## search location is the initial directory where the search begins, including its subdirectories

search_filter='your_file_filter'
search_location='/path/to/your/certificate/directory'

##############################################################################
fatal_error() {
##############################################################################

  echo "--- ERROR: $@" >&2
  echo
  exit 2
}

##############################################################################
## MAIN
##############################################################################

## HOUSEKEEPING
##

## Check if BASH
[[ "$(basename "$BASH")" != "bash" ]] && fatal_error "bash required; do not run it with $(basename "$BASH")!"

## Check if running as root or sudo
[[ $EUID -ne 0 ]] && fatal_error 'this script must be run as root or sudo!'

## FIND LOCATION OF NEW CERTIFICATE AND SET ENVIRONMENT VARIABLES
##

## Find the directory containing the most recent file matching your search filter and search location
search_result="$( find "$search_location" -type f -name "$search_filter" -exec ls -t {} +  2>/dev/null | head -n 1 )"
[[ -z "$search_result" ]] && fatal_error "empty search resut for the provided search filter and search location!"
search_result_dir="$( dirname "$search_result" )"

## Export environment variables
export SYNO_HELPER_KEY="${search_result_dir}/privkey.pem"
export SYNO_HELPER_FULLCHAIN="${search_result_dir}/fullchain.pem"
