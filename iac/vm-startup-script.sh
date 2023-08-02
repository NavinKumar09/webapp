#!/bin/bash
sudo apt update
sudo apt install nodejs

#Ops Agent Installation
# curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
# sudo bash add-google-cloud-ops-agent-repo.sh --also-install

git clone https://github.com/NavinKumar09/webapp.git
cd webapp
npm install
chmod +x app.js
node app.js