# Introduction
This is a simple script to get the machine's IP address and update cloudflare's DNS records.

# Installation
```shell 
git clone repository
```
# Usage
1. Clone repository locally
2. Setup a secrets.sh file to source Cloudflare auth variables
3. Setup cronjob to run script every minute
4. [Optional] Setup slack webhook uri in secrets.sh to allow for script to post slack messages.
