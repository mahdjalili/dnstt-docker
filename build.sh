#!/bin/bash


echo "Building dnstt-server Docker image for amd64..."
docker build --platform linux/amd64 -t dnstt-server:latest-amd64 .

