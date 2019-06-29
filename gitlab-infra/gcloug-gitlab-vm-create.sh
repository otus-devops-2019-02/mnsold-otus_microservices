#!/bin/bash

gcloud compute instances create gitlab-ci \
--project=docker-otus-201905 \
--image-project=ubuntu-os-cloud \
--image-family ubuntu-1604-lts \
--boot-disk-size=100GB \
--machine-type=n1-standard-1 \
--tags gitlab,http-server,https-server \
--network=default \
--zone europe-west1-b \
--restart-on-failure
