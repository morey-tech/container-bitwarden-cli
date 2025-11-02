#!/bin/bash
set -e

echo ''
echo 'Configuring Bitwarden CLI server URL'
echo ''
bw config server ${BW_HOST}

echo ''
echo 'Logging into Bitwarden CLI'
echo ''
bw login --apikey
export BW_SESSION=$(bw unlock ${BW_PASSWORD} --raw)

echo ''
echo 'Validating Bitwarden unlock'
echo ''
bw unlock --check

echo ''
echo 'Running `bw server` on port 8087'
echo ''
bw serve --hostname 0.0.0.0 #--disable-origin-protection
