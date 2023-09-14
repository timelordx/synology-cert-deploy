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

VERSION=0.2
SCRIPT_NAME="Synology Certificate Deployer v${VERSION}"

## Inspired by people and code in:
## - https://gist.github.com/catchdave/69854624a21ac75194706ec20ca61327
## - https://github.com/telnetdoogie/synology-scripts/blob/main/replace_synology_ssl_certs.sh
##
## ShellCheck verified: https://www.shellcheck.net/
# shellcheck disable=SC2145

##############################################################################
## SCRIPT CONFIG
##############################################################################

## New private key and full certificate chain file locations on your Synology
new_key='/path/to/your/privkey.pem'
new_fullchain='/path/to/your/fullchain.pem'

## Services / Packages on your Synology to RESTART (exact, case sensitive names)
services_to_restart=()
packages_to_restart=()

## Services / Packages on your Synology to IGNORE (exact, case sensitive names)
services_to_ignore=()
packages_to_ignore=()

##############################################################################
usage() {
##############################################################################
cat << EOF

$SCRIPT_NAME

An automated tool for easy TLS certificate deployment on Synology DSM. Takes
private key and full certificate chain files as input. Detects deployment
locations, and services and packages requiring restart. Streamlines activation
of a custom TLS certificate, assuming the presence of a default certificate 
(often Synology's self-signed certificate).

usage: $(basename "$0") [OPTION]

OPTION:

    -f, --force     forced key/certificate/chain/fullchain deployment
    -h, --help      show this help
    -n, --dry-run   perform a trial run (no actual changes will be applied, 
                    even with -f, --force enabled)

INSTRUCTIONS:

Before running the script, please edit the 'SCRIPT CONFIG' section and provide
the following information:

1. Private Key Location:
   To specify the location of the new private key, you have two options:

   a. Manual Assignment: Set the script variable 'new_key' to the desired
      file path.
   
   Example:
   
      new_key="/path/to/your/privkey.pem"

   b. Environment Variable: Alternatively, use 'SYNO_HELPER_KEY'. If it exists
      and isn't empty, it'll be automatically used for 'new_key'.

   Example:

      export SYNO_HELPER_KEY="/path/to/your/privkey.pem"

   If both methods are used, the external environment variable takes precedence.

2. Full Certificate Chain Location:
   To specify the location of the file containing the full certificate chain
   (server certificate and intermediate certificates), you have two options:

   a. Manual Assignment: set the script variable 'new_fullchain' to the desired
      file path.
   
   Example:
   
      new_fullchain="/path/to/your/fullchain.pem"

   b. Environment Variable: Alternatively, use 'SYNO_HELPER_FULLCHAIN'. If it
      exists and isn't empty, it'll be automatically used for 'new_fullchain'.

   Example:

      export SYNO_HELPER_FULLCHAIN="/path/to/your/fullchain.pem"

   If both methods are used, the external environment variable takes precedence.

3. Services and Packages to Restart:
   If there are any additional services or packages that need to be restarted
   after the certificate deployment, add them to the 'services_to_restart' or
   'packages_to_restart' array. Separate each service/package name with a
   space. 
   
   Example:

      services_to_restart=("service1" "service2")
      packages_to_restart=("package1" "package2")

4. Services and Packages to Ignore:
   If there are any services or packages that should be ignored and not
   restarted when the script runs, add them to the 'services_to_ignore' or
   'packages_to_ignore' array. Separate each service/package name with a
   space. 
   
   Example:

      services_to_ignore=("service3" "service4")
      packages_to_ignore=("package3" "package4")

Note: Please ensure the paths and names provided in the 'SCRIPT CONFIG' section
are accurate and valid for your Synology DSM system.

Once you have edited the 'SCRIPT CONFIG' section with the appropriate values,
you can proceed to run the script for automated TLS certificate deployment on
Synology DSM.

Ensure you run the script with root privileges (using sudo) to avoid any
permission issues during the certificate deployment process. For automated
execution, consider setting up the script as a Scheduled Task in Task Scheduler
to run as root once a week.

EOF
}

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

## Check script parameters
force=0
dry_run=0

for arg in "$@"; do
  case "$arg" in
    -f | --force )
        force=1
        ;;
    -h | --help )
        usage
        exit 1
        ;;
    -n | --dry-run )
        dry_run=1
        ;;
    *)
        usage
        fatal_error "unrecognized option or argument '${arg}'!"
        ;;
  esac
done

[[ $dry_run -eq 1 ]] && printf '\n[!!!] Running a trial run (no actual changes are being applied right now)!\n\n'

## External environment variables SYNO_HELPER_KEY and SYNO_HELPER_FULLCHAIN 
## take precendence if they exist and have non-empty values
[[ -n "$SYNO_HELPER_KEY"       ]] && new_key="$SYNO_HELPER_KEY"
[[ -n "$SYNO_HELPER_FULLCHAIN" ]] && new_fullchain="$SYNO_HELPER_FULLCHAIN"

## COLLECT NEW PEM FILES
##

## Extract privkey, cert, chain and fullchain from new_key and new_fullchain
privkey_pem="$( openssl pkey -in "$new_key" -out - 2>/dev/null )"
cert_pem="$( openssl x509 -in "$new_fullchain" -outform PEM -out - 2>/dev/null  )"
fullchain_pem="$( grep -v -E '^\s*$' "$new_fullchain" 2>/dev/null )"
chain_pem="$( diff <( echo "$cert_pem" ) <( echo "$fullchain_pem" ) 2>/dev/null | grep -E '^> ' | sed 's/^> //g' )"

## Check mandatory extracts
[[ -z "$privkey_pem"   ]] && fatal_error "new private key is empty!"
[[ -z "$cert_pem"      ]] && fatal_error "new certificate is empty!"
[[ -z "$fullchain_pem" ]] && fatal_error "new fullchain is empty!"

## Calculate MD5 of new cert
cert_pem_md5="$( md5sum <<< "$cert_pem" | awk '{print $1}' )"

## DEPLOY NEW PEM FILES
##

## Get location of Synology default certificate
syno_cert_root='/usr/syno/etc/certificate'
[[ ! -f "${syno_cert_root}/_archive/DEFAULT" ]] && fatal_error "default certificate not found!"
syno_cert_default_name="$( < "${syno_cert_root}/_archive/DEFAULT" )"
syno_cert_default_dir="${syno_cert_root}/_archive/${syno_cert_default_name}"

## Calculate MD5 of default Synology certificate
syno_cert_md5="$( md5sum "${syno_cert_default_dir}/cert.pem" | awk '{print $1}' )"

## Check if new and default Synology certificates differ and deploy if needed
grep -q "$syno_cert_md5" <<< "$cert_pem_md5"
deploy_default=$?
[[ $force -eq 1 ]] && deploy_default=1
if [[ $deploy_default -eq 1 ]]; then
  echo "[default] deploying certificate to ${syno_cert_default_name}"
  if [[ $dry_run -ne 1 ]]; then
    echo "$privkey_pem"   > "${syno_cert_default_dir}/privkey.pem"
    echo "$cert_pem"      > "${syno_cert_default_dir}/cert.pem"
    echo "$fullchain_pem" > "${syno_cert_default_dir}/fullchain.pem"
    echo "$chain_pem"     > "${syno_cert_default_dir}/chain.pem"
  fi
fi

## Synology certificate folders
service_cert_dirs="$( find /usr/syno/etc/certificate  -name 'cert.pem' -exec dirname {} \; 2>/dev/null )"
package_cert_dirs="$( find /usr/local/etc/certificate -name 'cert.pem' -exec dirname {} \; 2>/dev/null )"

## Services to always ignore
services_to_ignore+=( '_archive' 'system' 'ReverseProxy' )

## Services
for service in $service_cert_dirs; do
  
  ## Get service name
  service_name="$( grep -Po '/usr/syno/etc/certificate/\K[^/]+' <<< "$service" )"
  
  ## Check if service_name is in services_to_ignore
  printf '%s\0' "${services_to_ignore[@]}" | grep -Fxzq -- "$service_name"
  
  ## If it's not
  if [[ $? -eq 1 ]]; then
    
    ## Check if new and service certificates differ and deploy if needed
    service_cert_md5="$( md5sum "${service}/cert.pem" | awk '{print $1}' )"
    grep -q "$service_cert_md5" <<< "$cert_pem_md5"
    deploy_service=$?
    [[ $force -eq 1 ]] && deploy_service=1
    if [[ $deploy_service -eq 1 ]]; then
      echo "[service] deploying certificate to ${service_name}"
      if [[ $dry_run -ne 1 ]]; then
        echo "$privkey_pem"   > "${service}/privkey.pem"
        echo "$cert_pem"      > "${service}/cert.pem"
        echo "$fullchain_pem" > "${service}/fullchain.pem"
        echo "$chain_pem"     > "${service}/chain.pem"
      fi
      
      ## check if service is running and needs to be restarted
      [[ "$( synosystemctl get-active-status "$service_name" )" == "active" ]] && services_to_restart+=( "$service_name" )
    fi
  fi
done

## Packages
for package in $package_cert_dirs; do
  
  ## Get package name
  package_name="$( grep -Po '/usr/local/etc/certificate/\K[^/]+' <<< "$package" )"
  
  ## Check if package_name is in packages_to_ignore
  printf '%s\0' "${packages_to_ignore[@]}" | grep -Fxzq -- "$package_name"
  
  ## If it's not
  if [[ $? -eq 1 ]]; then
    
    ## Check if new and package certificates differ and deploy if needed
    package_cert_md5="$( md5sum "${package}/cert.pem" | awk '{print $1}' )"
    grep -q "$package_cert_md5" <<< "$cert_pem_md5"
    deploy_package=$?
    [[ $force -eq 1 ]] && deploy_package=1
    if [[ $deploy_package -eq 1 ]]; then
      echo "[package] deploying certificate to ${package_name}"
      if [[ $dry_run -ne 1 ]]; then
        echo "$privkey_pem"   > "${package}/privkey.pem"
        echo "$cert_pem"      > "${package}/cert.pem"
        echo "$fullchain_pem" > "${package}/fullchain.pem"
        echo "$chain_pem"     > "${package}/chain.pem"
      fi
      
      ## check if package is running and needs to be restarted
      synopkg is_onoff "$package_name" >/dev/null && packages_to_restart+=("$package_name")
    fi
  fi
done

## RESTART SYNOLOGY SERVICES AND PACKAGES
##

## Services
for service in "${services_to_restart[@]}"; do
  echo "[service] restarting ${service}"
  [[ $dry_run -ne 1 ]] && synosystemctl restart "$service"
done

## Packages
for package in "${packages_to_restart[@]}"; do
  echo "[package] restarting ${package}"
  [[ $dry_run -ne 1 ]] && synopkg restart "$package"
done

## Default
if [[ $deploy_default -eq 1 ]]; then
  echo "[default] prepping nginx"
  [[ $dry_run -ne 1 ]] && synow3tool --gen-all
  
  echo "[default] reloading nginx"
  [[ $dry_run -ne 1 ]] && synow3tool --nginx=reload
  
  echo "[default] restarting DSM web portal"
  [[ $dry_run -ne 1 ]] && synow3tool --restart-dsm-service
fi
