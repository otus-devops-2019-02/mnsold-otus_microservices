# Автоматизация развертывания и регистрации Gitlab CI Runner

  Общая идея создания множества ранеров представлена в bash скрипте.

  В качестве некоторого завершенного решения можно завернуть скрипт в ansible, развертывание ВМ сделать в терраформ, тогда можно будет обеспечить масштабирование: нужное количество ВМ с нужным количеством ранеров в каждой ВМ.

  Чтобы совсем все было хорошо и авто масштабирование работало в полной мере, смотрим в конфиг `/etc/gitlab-runner/config.toml` и документацию Runners autoscale configuration  https://docs.gitlab.com/runner/configuration/autoscale.html

```bash
GITLAB_SERVER_URL="http://35.205.50.178/"
GITLAB_PROJECT_REGISTRATION_TOKEN="TYkzx8HKZ5MH67SAR4_y"
GITLAB_RUNNER_CONTEINER_COUNT=2
GITLAB_RUNNER_CONTEINER_PREFIX="gitlab-runner"
GITLAB_RUNNER_EXECUTOR="docker"
GITLAB_RUNNER_DOCKER_IMAGE="gitlab/gitlab-runner:latest"
GITLAB_RUNNER_TAG_LIST_COMMA="docker"

for ((i=1;i<=$GITLAB_RUNNER_CONTEINER_COUNT;i++)); do 
    GITLAB_RUNNER_CONTEINER_NAME=$GITLAB_RUNNER_CONTEINER_PREFIX$i
    
    echo "Create container: $GITLAB_RUNNER_CONTEINER_NAME"
    
    sudo docker run -d --name $GITLAB_RUNNER_CONTEINER_NAME --restart always \
        -v /srv/gitlab-runner/config:/etc/gitlab-runner \
        -v /var/run/docker.sock:/var/run/docker.sock \
        gitlab/gitlab-runner:latest
    
    sudo docker exec -it $GITLAB_RUNNER_CONTEINER_NAME gitlab-runner register \
        --non-interactive \
        --url "$GITLAB_SERVER_URL" \
        --registration-token "$GITLAB_PROJECT_REGISTRATION_TOKEN" \
        --executor "$GITLAB_RUNNER_EXECUTOR" \
        --docker-image "$GITLAB_RUNNER_DOCKER_IMAGE" \
        --description "$GITLAB_RUNNER_CONTEINER_NAME_$GITLAB_RUNNER_EXECUTOR-runner" \
        --tag-list "$GITLAB_RUNNER_TAG_LIST_COMMA" \
        --run-untagged="true" \
        --locked="false"
done
```

Вывод скрипта:

```properties
Create container: gitlab-runner1
ca08e6342a97030c86709c2522be1c45b8cbda4c28e2311f3f25dd8fe688eaae
Runtime platform                                    arch=amd64 os=linux pid=12 revision=5a147c92 version=11.11.1
Running in system-mode.

Registering runner... succeeded                     runner=TYkzx8HK
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
Create container: gitlab-runner2
5cf4a73e3a516482781cc2cda9775291bf767614e494beb682cdae9d819be780
Runtime platform                                    arch=amd64 os=linux pid=12 revision=5a147c92 version=11.11.1
Running in system-mode.

Registering runner... succeeded                     runner=TYkzx8HK
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!

```
