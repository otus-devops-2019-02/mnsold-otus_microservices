#!/bin/bash

# создать docker machine
export GOOGLE_PROJECT=docker-otus-201905

#для чистоты, удалим ее если она была
docker-machine rm docker-host

docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-zone europe-west1-b \
    docker-host

# посмотреть на ВМ
docker-machine ls

# переключиться на docker-machine
eval $(docker-machine env docker-host)
