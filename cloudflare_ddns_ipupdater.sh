#!/bin/bash
####################################################
################ secrets.sh sample #################
####################################################
# token=""
# auth_email=""
# zone_id=""
# record_name=""
# slack_uri=""

####################################################
################ crontab script ####################
####################################################
# Copy and uncomment the below script in crontab -e to run this update every minute
# to view logs use grep "cfddns" /var/log/syslog
# */1 * * * * ~/cloudflare_ddns_ipupdater.sh 2>&1 | logger -t cfddns 

#source secrets file for variables
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/secrets.sh


token=$token                # global token by default
auth_email=$auth_email      # cloudflare email
zone_id=$zone_id            # zone identifier for website in cloudflare
record_name=$record_name    # record name to change eg. wgvpn.benleejc.com
slack_uri=$slack_uri        # slack webhook endpoint for messages
auth_type="global"          # uses global by defaul
proxied="false"             # proxy false by default

if [[ $token == "" ]]; then
    logger -s "Cloudflare DNS IP Updater: WARNING Token not set."
    exit 1
fi


# check existing record exists
record=$(curl --request GET \
  --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$record_name"\
  --header "Content-Type: application/json" \
  --header "X-Auth-Email: $auth_email" \
  --header "X-Auth-Key: $token")

if [[ $record =~ \"count\":[2-9] ]]; then
    logger -s "Cloudflare DNS IP updater: Multiple records for (${record_name}) found."
    exit 1
fi
if [[ $record =~ \"count\":0 ]]; then
    logger -s "Cloudflare DNS IP updater: Record doesn't exist. Please create one for (${record_name}) first"
    exit 1
fi
if [[ $record =~ \"count\":1 ]]; then
    echo "Record found!"
fi

# get existing variables from dns record
old_ip=$(echo $record | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
record_id=$(echo "$record" | sed -E 's/.*"id":"([^,]+)".*/\1/')

# get public ip
ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
if [[ ! $ret == 0 ]]; then
    # backup ip provider
    echo $ret
    ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
else
    ip=$(echo $ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
fi

# verify ip is valid
if [[ ! $ip =~ $ipv4_regex ]]; then
    logger -s "Cloudflare DNS IP updater: Invalid IP"
    exit 2
fi

# compare ip
if [[ $ip == $old_ip ]]; then
    logger -s "Cloudflare DNS IP updater: IP already exists. No change needed."
    exit 0
fi

# update ip using API
update=$(curl --request PUT \
  --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
  --header "Content-Type: application/json" \
  --header "X-Auth-Email: $auth_email" \
  --header "X-Auth-Key: $token" \
  --data "{\"content\":\"$ip\",\"name\":\"$record_name\",\"proxied\":${proxied},\"type\":\"A\",\"ttl\": 3600}")

if [[ $update =~ \"success\":false\" ]]; then
    message="Cloudflare DNS IP updater: IP failed to update"
    logger -s $message
else
    message="Cloudflare DNS IP updater: $record_name IP updated from $old_ip to $ip"
    logger -s $message
fi

# send update to slack
if [[ ! $slack_uri == "" ]]; then
    slack_update=$(curl -X POST \
        --url "https://hooks.slack.com/services/$slack_uri" \
        --header 'Content-type: application/json' \
        --data "{\"text\":\"$message\"}" )
fi


