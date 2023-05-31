#!bin/bash
source secrets.sh

token=$token
auth_email=$auth_email
auth_type=$auth_type
zone_id=$zone_id
record_name=$record_name

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


