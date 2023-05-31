#!bin/bash
#source secrets file for variables
source secrets.sh

token=$token
auth_email=$auth_email
auth_type="global"
zone_id=$zone_id
record_name=$record_name
proxied="false"

# check existing record exists
record=$(curl --request GET \
  --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$record_name"\
  --header "Content-Type: application/json" \
  --header "X-Auth-Email: $auth_email" \
  --header "X-Auth-Key: $token")

if [[ $record =~ \"count\":[2-9] ]]; then
    logger -s "DDNS Updater: Multiple records for (${record_name}) found."
    exit 1
fi
if [[ $record =~ \"count\":0 ]]; then
    logger -s "DDNS Updater: Record doesn't exist. Please create one for (${record_name}) first"
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
    logger -s "DDNS Updater: Invalid IP"
    exit 2
fi

# compare ip
if [[ $ip == $old_ip ]]; then
    logger -s "DDNS Updater: IP already exists. No change needed."
    exit 0
fi

# update ip using API
update=$(curl --request PUT \
  --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
  --header "Content-Type: application/json" \
  --header "X-Auth-Email: $auth_email" \
  --header "X-Auth-Key: $token" \
  --data "{\"content\":\"$ip\",\"name\":\"$record_name\",\"proxied\":${proxied},\"type\":\"A\",\"ttl\": 3600}")

# TODO send update to slack
if [[ $update =~ \"success\":false\" ]]; then
    logger -s "DDNS Updater: IP failed to update"
    exit 1
else
    logger -s "DDNS Updater: $record_name IP updated from $old_ip to $ip"
fi

