#!/bin/bash

# Configuration file
config="./.config"

# Read configuration file and build array (cfg)
IFS=$'\r\n' GLOBIGNORE='*' command eval 'cfg=($(cat ${config}))'
cfg_len="${#cfg[@]}"
if [[ $cfg_len -lt 3 ]]; then
  echo "Invaid Configuration File"
  exit 3
fi

# Assign values from config to variables
mydomain="${cfg[0]}"
myhostname="${cfg[1]}"
gdapikey="${cfg[2]}"

# Attempt to lookup IP address
myip=`curl -s "https://api.ipify.org"`
# Alternate lookup site
myip2=`curl -s "https://diagnostic.opendns.com/myip"`
# If the results differ:
if [[ "$myip" != "$myip2" ]]; then
  # Check if both IPs are valid
  myip_valid=`echo $myip | grep -Po "(\d+\.?)*"`
  myip2_valid=`echo $myip2 | grep -Po "(\d+\.?)*"`
  # If result of the validity check is NULL:
  if [[ -z "$myip_valid" ]]; then
    # Check the alternate IP for validity
    if [[ -z "$myip2_valid" ]]; then
      # If both IPS are invalid exit
      echo "Unable to lookup IP address"
      exit 1
    # If the primary lookup method fails while the alternate is successful and results
    # in a valid IP set $myip to $myip2
    else
      myip=$myip2
    fi
  fi
fi

# In the case where both lookup methods return NULL - exit
if [[ -z "$myip" ]]; then
  echo "Unable to lookup IP address"
  exit 2
fi

# Execute GET request on the godaddy API
dnsdata=`curl -s -X GET -H "Authorization: sso-key ${gdapikey}" "https://api.godaddy.com/v1/domains/${mydomain}/records/A/${myhostname}"`

# Parse response
tmp=`echo $dnsdata | cut -d ',' -f 1 | tr -d '"' | cut -d ":" -f 2`
gdip=`echo $tmp | grep -Po "^(\d+\.?)*"`
if [[ -z "$gdip" ]]; then
  echo "Bad GoDaddy response, check configuration file"
  exit 4
fi

echo "`date '+%Y-%m-%d %H:%M:%S'` - Current External IP is $myip, GoDaddy DNS IP is $gdip"

# Does DNS record need updating?
if [ "$gdip" != "$myip" ]; then
  echo "IP's differ, updating record"
  curl -s -X PUT "https://api.godaddy.com/v1/domains/${mydomain}/records/A/${myhostname}" -H "Authorization: sso-key ${gdapikey}" -H "Content-Type: application/json" -d "[{\"data\": \"${myip}\"}]"
fi
