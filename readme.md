# Introduction
This is a simple script to get the machine's IP address and update cloudflare's DNS records.

# Installation
```shell 
git clone https://github.com/benleejc/cloudflare_ddns_ipupdater.git
```
# Usage
1. Clone repository locally
2. Setup a secrets.sh file to source Cloudflare auth variables
3. Set permissions for script `chmod +x cloudflare_ddns_ipupdater.sh`
4. Setup cronjob to run script every minute
5. [Optional] Setup slack webhook uri in secrets.sh to allow for script to post slack messages.
