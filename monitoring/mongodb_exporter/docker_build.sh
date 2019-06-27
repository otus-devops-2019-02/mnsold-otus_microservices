#!/bin/bash

# docker build https://docs.docker.com/engine/reference/commandline/build/
#  для этого репозитория нельзя использовать сборку образа вида:
# docker build -t mnsoldotus/prometheus_mongodb_exporter:${VERSION} https://github.com/percona/mongodb_exporter.git#${VERSION}:/go/src/github.com/percona/mongodb_exporter
# т.к. согласно докам докера,
# при сборке образа из ссылки git'а история не коммитов сохранятеся (см раздел Git repositories: "The commit history is not preserved." )
# а build используемый в Dockerfile обращается к коммитам и тегам
#

VERSION=v0.7.0
echo "Cloning repo percona/mongodb_export version ${VERSION}"
git clone https://github.com/percona/mongodb_exporter.git -b v0.7.0 /tmp/mongodb_exporter

echo "Build docker image"
docker build -t mnsoldotus/prometheus_mongodb_exporter:${VERSION} /tmp/mongodb_exporter

echo "Remove local repo percona/mongodb_export"
rm -Rf /tmp/mongodb_exporter

echo "Push docker image"
docker login
docker push mnsoldotus/prometheus_mongodb_exporter:${VERSION}
