#!make
export USERNAME=mnsoldotus
export APP_POST_VERSION=logging
export APP_COMMENT_VERSION=logging
export APP_UI_VERSION=logging

all : docker-build-comment docker-push-comment docker-build-post docker-push-post docker-build-ui docker-push-ui docker-build-prometheus docker-push-prometheus docker-build-mongodb_exporter docker-push-mongodb_exporter docker-build-alertmanager docker-push-alertmanager docker-build-telegraf docker-push-telegraf

.PHONY : all

######################################
# COMMENT
docker-build-comment:
	cd ../src/comment && ./docker_build.sh

docker-push-comment:
	docker login && docker push $(USERNAME)/comment:$(APP_COMMENT_VERSION)

######################################
# POST
docker-build-post:
	cd ../src/post-py && ./docker_build.sh

docker-push-post:
	docker login && docker push $(USERNAME)/post:$(APP_POST_VERSION)

######################################
# UI
docker-build-ui:
	cd ../src/ui && ./docker_build.sh

docker-push-ui:
	docker login && docker push $(USERNAME)/ui:$(APP_UI_VERSION)

######################################
# PROMETHEUS
docker-push-prometheus:
	docker login && docker push $(USERNAME)/prometheus

docker-build-prometheus:
	cd ../monitoring/prometheus && docker build -t $(USERNAME)/prometheus .

######################################
# PROMETHEUS MONGODB EXPORTER
docker-build-mongodb_exporter:
	cd ../monitoring/mongodb_exporter && ./docker_build.sh

docker-push-mongodb_exporter:
	docker login && docker push $(USERNAME)/prometheus_mongodb_exporter:v0.7.0

######################################
# PROMETHEUS ALERTMANAGER
docker-build-alertmanager:
	cd ../monitoring/alertmanager && docker build -t $(USERNAME)/alertmanager .

docker-push-alertmanager:
	docker login && docker push $(USERNAME)/alertmanager

######################################
# PROMETHEUS TELEGRAF
docker-build-telegraf:
	cd ../monitoring/telegraf && docker build -t $(USERNAME)/telegraf .

docker-push-telegraf:
	docker login && docker push $(USERNAME)/telegraf
