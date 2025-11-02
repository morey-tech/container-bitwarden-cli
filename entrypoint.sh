#!/bin/bash
set -e
export BITWARDENCLI_DEBUG=false

echo "Bitwarden CLI version $(bw --version)"

echo 'Configuring Bitwarden CLI server URL'
bw config server ${BW_HOST} --nointeraction
echo ''

echo 'Logging into Bitwarden CLI'
bw login --apikey --nointeraction
export BW_SESSION=$(bw unlock ${BW_PASSWORD} --raw)
echo ''

echo 'Validating Bitwarden unlock'
bw unlock --check --nointeraction
echo ''

echo 'Running `bw server` on port 8087'
bw serve --hostname 0.0.0.0 --port 8087 --nointeraction
