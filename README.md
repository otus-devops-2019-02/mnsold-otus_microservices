# mnsold-otus_microservices
mnsold-otus microservices repository

# ДЗ№14

- Доработана роль anasible-galaxy geerlingguy.docker до установки docker-machine

- Установлено ПО

  ```bash
  docker --version
  Docker version 18.06.3-ce, build d7080c1

  docker-compose version
  docker-compose version 1.24.0, build 0aa59064
  docker-py version: 3.7.2
  CPython version: 3.6.8
  OpenSSL version: OpenSSL 1.1.0j  20 Nov 2018

  docker-machine version
  docker-machine version 0.16.0, build 702c267f
  ```

- Запущен контейнер `docker run hello-world`

- Опробованы команды `docker ps` `docker ps -a` `docker images`

- Создали контейнер, вошли в bash `docker run -it ubuntu:16.04 /bin/bash` и создали там файл, затем создали еще один контейнер аналогичной командой, созданого файла там нет, т.к. мы не запустили ранее созданный контейнер, создали новый директивой `run`

- Запустили ранее созданный контейнер через conteqner_id командой`docker start container_id`

- Подключились к терминалу директивой `docker attach container_id` , вышли из контейнера не останавливая его `Ctrl+p`, `Ctrl+q`

- Рассмотрели парамерты команды `docker`

- Подключились к контейнеру`docker exec -it container_id bash`, с запуском нового процесса bash внутри контейнера

- Создали новый имидж с запущенного контейнера `docker commit container_id`

- Рассмотрены директивы `stop` `kill` по остановке и принудительному завершению процесса

- Рассмотрена директива `system df` по тотбражению использования дискового пространства занятого / может быть освобождено

- Рассмотрены директивы `rm` `rmi` по удалению контейнера и имиджа

ДЗ№15
# ДЗ №15

## Создание хостовой машины docker-machine в GCP

```bash
export GOOGLE_PROJECT=docker-otus-201905
```

```bash
# создать docker-machine
export GOOGLE_PROJECT=<GCP_PROJECT>
docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-zone europe-west1-b \
    docker-host

# список хостов docker-machine
docker-machine ls

# указать окружение хоста docker-machine c установленным docker-engine, с которым будем работать
eval $(docker-machine env docker-host)
#посмотреть какие переменные установились
set|grep DOCKER_*
DOCKER_CERT_PATH=/home/mnsold/.docker/machine/machines/docker-host
DOCKER_HOST=tcp://35.241.251.193:2376
DOCKER_MACHINE_NAME=docker-host
DOCKER_TLS_VERIFY=1


# переключиться в локальное окружение
eval $(docker-machine env --unset)
```

Проверка

```bash
docker-machine ls
NAME          ACTIVE   DRIVER   STATE     URL                         SWARM   DOCKER     ERRORS
docker-host   *        google   Running   tcp://35.241.251.193:2376           v18.09.6

echo $DOCKER_MACHINE_NAME
docker-host

docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
reddit              latest              ba6d8bfedfae        4 minutes ago       682MB

# переключаемся в локальное окружение, ничего нет, все на удаленной машине
docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
```

## Задание со *

### Создать storage сегмент

backend для хранения состояния terraform

```bash
cd /docker-monolith/infra/terraform/backend
terraform init

terraform apply
```

### Поднять пул инстансов terraform

```bash
cd docker-monolith/infra/terraform/stage
terraform init

# module.vpc временно отключен, выполнять не требуется
#terraform import module.vpc.google_compute_firewall.firewall_ssh default-allow-ssh
terraform apply
```

Пригодится:

- указать статический IP для пула инстансов

  https://stackoverflow.com/questions/46618068/deploy-gcp-instance-using-terraform-and-count-with-attached-disk

### Плейбуки ansible с динамическим инвентори

- Запустить основной плейбук, который установит питон (base.yml), докер (docker.yml), развернет приложение (deploy.yml)

```bash
cd docker-monolith/infra/ansible

ansible-playbook playbooks/main-site.yml
```

- Проверка

  Прейти по ссылке http://<terraform output http_lb_external_ip>:9292

- Примечание:

  Т.к. используется динамический инвентори, который возвращает docker-machine в GCP и которой не должны применяться плейбуки, то

  - все хосты проекта должны быть определены в инвентори
  - в плейбуках указано не применять к хостам, которые находятся не в группах `hosts: all:!ungrouped`, либо указывается конкретная кгруппа к которой требуется применять плейбук, чтобы плейбуки не применяись к docker-machine и обходили этот хост стороной

  PS: ! В последующем, точнее в ДЗ №19, отказался от `hosts: all:!ungrouped`, если нужно, чтобы ansible не выполнялся на не нужных хостах, нужно добавить ключ `-l <название группы>|<название хоста>`, в данном случае нужно использовать название группы `app`

### Образ packer'а с установленным docker

```bash
cd docker-monolith/infra/

packer build -var-file=packer/variables.json packer/docker.json
```

- Проверка

```bash
gcloud compute instances create packer-docker \
--boot-disk-size=10GB \
--image-family ubuntu-docker-base \
--image-project=docker-otus-201905 \
--machine-type=g1-small \
--tags docker-base \
--zone europe-west1-b \
--restart-on-failure


ssh appuser@<EXTERNAL_IP> -i ~/.ssh/appuser
docker --version
Docker version 18.06.3-ce, build d7080c1

gcloud compute instances delete packer-docker --zone europe-west1-b --delete-disks=all
```

Примечание:

Было замечено, что сборка может упасть с ошибкой `Unable to locate package python-minimal`, но если запустить сборку еще раз без каких либо изменений, то сборка проходит успешно, возможно этто коссяк какого-то образа и нужно зафиксировать конкретный образ для сборки, или предварительно проверить/установить некоторые репозитории типа `universe`.

# ДЗ №16

- Написаны Dockerfiles для 3 компонентов: `post-py` - сервис отвечающий за написание постов; `comment` - сервис отвечающий за написание комментариев; `ui` - веб-интерфейс, работающий с другими сервисами.

- Выполнена сборка образов и запущены приложения

Создать сеть

```
docker network create reddit
```

Сборка образов

```
docker build -t mnsoldotus/post:1.0 ./post-py
docker build -t mnsoldotus/comment:1.0 ./comment
docker build -t mnsoldotus/ui:1.0 ./ui -f ui/Dockerfile.1
```

Создать том

```
docker volume create reddit_db
```

Задание со * (стр. 15). Запуск контейнеров с др алиасами

```bash
docker kill $(docker ps -q)

docker run -d \
--network=reddit \
--network-alias=post_db_test \
--network-alias=comment_db_test \
-v reddit_db:/data/db \
mongo:latest

docker run -d \
--network=reddit \
--network-alias=post_test \
--env POST_DATABASE_HOST=post_db_test \
mnsoldotus/post:1.0

docker run -d \
--network=reddit \
--network-alias=comment_test \
--env COMMENT_DATABASE_HOST=comment_db_test \
mnsoldotus/comment:1.0

docker run -d \
--network=reddit \
--env POST_SERVICE_HOST=post_test \
--env COMMENT_SERVICE_HOST=comment_test \
-p 9292:9292 \
mnsoldotus/ui:1.0

```

- Выполнено улучшение образа `ui`:

  - Вариант 1. на основе базового образа `ubuntu:16.04` (см коммит файла `src/ui/Dockerfile`)
  - Вариант 2. на основе базового образа `alpine:3.9` (см файл `src/ui/Dockerfile)
  - Вариант 3. на основе базового образа `ruby:alpine3.9` (см файл `src/ui/Dockerfile.1`)

  Примечание: в каждом из последующих вариантов размер образа меньше чем в предыдущем варианте

#ДЗ №17

## Сети

- Рассмотрены сетевые драйверы `bridge` `host` `none`

- Созданы сети для приложений фрона и бекэнда (ui только во фронте, сервисы во фронте и бэкенде, БД только в бэкенде):

  ```bash
  docker network create back_net  --subnet=10.0.2.0/24
  docker network create front_net --subnet=10.0.1.0/24
  ```

- Созданы контейнеры в разных сетях
  ```bash
  docker run -d --network=back_net --network-alias=post_db --network-alias=comment_db  --name mongo_db mongo:latest
  docker run -d --network=back_net --network-alias=post --name post mnsoldotus/post:1.0
  docker run -d --network=back_net --network-alias=comment --name comment mnsoldotus/comment:1.0
  docker run -d --network=front_net -p 9292:9292 --name ui mnsoldotus/ui:1.0
  ```

  Выполнено онлайн подключение контейнеров к сети

  ```bash
  docker network connect front_net post
  docker network connect front_net comment
  ```

- Рассмотрены сетевые интерфейсы со стороны хостовой машины

  ```bash
  docker network ls
  brctl show <interface>
  ```

- Рассмотрены правила iptables

  Цепочки `POSTROUTING`, `DOCKER` с правилом `DNAT`, процесса `docker-proxy` слушающего tcp порт

  ```bash
   sudo iptables -nL -t nat
   ps ax | grep docker-proxy
  ```

##docker-compose

- Установлен docker-compose version 1.24.0

- Выполнен запуск проекта с использованием docker-compose

  ```bash
  docker kill $(docker ps -q)

  export USERNAME=<docker_hub_login>
  cd src
  docker-compose up -d
  ```

  Посмотреть список контейнеров `docker-compose ps`

  Проверка http://< docker-machine-ip >:9292/

- Выполнена корректировка docker-compose на множество сетей, сетевых алиасов

- Выполнена параметризация docker-compose.yml переменными, указанными в файле `src/.env` в формате `VAR=VAL`

  https://docs.docker.com/compose/env-file/

- Наименованием проекта по умолчанию является `basename` директории в которой находится `docker-compose.yml`, изменить наименование проекта можно следующими способами:

  1. Переменной `COMPOSE_PROJECT_NAME` в файле `.env`. Пример `COMPOSE_PROJECT_NAME=docker4`

  2. Опцией docker-compose `-p, --project-name NAME`. Пример `docker-compose -p docker4 up -d`

     https://docs.docker.com/compose/reference/envvars/

## Задание со *

1. Обеспечить изменение кода каждого из приложений, не выполняя сборку образа:

   Смонтировать код приложений из соответствующих директорий `comment` `post-py` `ui` в `/app` через опцию  `volumes: ...`

   Примечание: т.к. кода на docker-host нет, нужно его туда сначала скопировать, либо монтировать локальную директорию на docker-host.

   PS:

   - docker-machine mount `cd src; docker-machine mount docker-host:/app ./`, использующий SSHFS, монтирует удаленную директорию в локальную, а не оборот, в прочем как и sshfs. Не умеет монтировать в не пустую директорию и выдает ошибку: "fuse: if you are sure this is safe, use the 'nonempty' mount option".
   - т.е. нужно монтировать с использованием sshfs + ssh forwarding  (reverse sshfs ) https://superuser.com/questions/616182/how-to-mount-local-directory-to-remote-like-sshfs

2. Обеспечить запуск puma для руби приложений в дебаг режиме с двумя воркерами (флаги --debug и -w 2):

   Переопределить директиву CMD докер образов с ruby приложениями опцией `command: ...`

Результат зафиксирован в файле `src/docker-compose.override.yml`

Запустить проект

- Вариант с копированием кода на удаленную машину

```bash
cd src/
docker-machine ssh docker-host "sudo mkdir /app; sudo chown -R docker-user /app"
docker-machine scp -r -d ./ docker-host:/app/
docker-machine ssh docker-host "chmod a-x /app/post-py/*.py"
docker-compose -f docker-compose.override.yml up -d

```

- вариант с монтированием локальной директории на удаленную машину (reverse sshfs )
```bash
# создать точку монтирования
localmachine$ уdocker-machine ssh docker-host "sudo mkdir /app"
# ssh forwarding
localmachine$ ssh docker-user@$(docker-machine ip docker-host) -i ~/.docker/machine/machines/docker-host/id_rsa -R 10000:localhost:22
# mount sshfs
remotemachine$ sudo sshfs -p 10000 -o allow_other <local_user_name>@localhost:/path/to/src /app

# в соседней сессии запусть контейнеры
localmachine$ cd src/; docker-compose -f docker-compose.override.yml up -d

#------------
# закончить тест
localmachine$ docker-compose -f docker-compose.override.yml down
remotemachine$ sudo fusermount -uz /app
```

PS: файлы .py не д.б. исполняемые, иначе будет ошибка при старте контейнера `cd src/; chmod -R a-x post-py/*.py`



# ДЗ №19

## Подготовка ВМ, инсталляция GitLAB

- Создать ВМ для GitLAB

```bash
cd gitlab-infra
./gcloug-gitlab-vm-create.sh
```

- Подготовить ВМ

```bash
cd gitlab-infra/ansible

# проверить, что gce возвращает список хостов
ansible-inventory --list -i env/stage/inventory.gcp.yml

#проверить доступность хоста gitlab
ansible gitlab -m ping

#установить docker, compose, gitlab на хосте группы gitlab (можно указать конкретный хост 'gitlab-ce', все равно там 1 хост)
ansible-playbook playbooks/gitlab.yml -l 'gitlab' -vvv
```

## Работа в Gitlab

- Закрыли регистрацию пользователей

- Создали группу `homework`, и проект в ней `example`

- Добавили ориджин к проекту git'а микросервисов, запушили бранч gitlab-ci-id в gitlab

- В корне проекта создали `.gitlab-ci.yml` простым пайплайном, запушили в GitLAB, созданный пайплайн доступен в разделе пайплайнов CI/CD, но не работает пока, т.к. нет Runner'ов и находится в статусе pending

- Регистрируем Runner в настройках проекта, разделе CI/CD -> Runners,

  - В "Set up a specific Runner manually" запоминаем токен

  - На хосте с GitLAB запускаем контейнер с Runner

    ```bash
    ssh appuser@35.205.50.178 -i ~/.ssh/appuser

    docker run -d --name gitlab-runner --restart always \
    -v /srv/gitlab-runner/config:/etc/gitlab-runner \
    -v /var/run/docker.sock:/var/run/docker.sock \
    gitlab/gitlab-runner:latest

    ```

    !!! Если нужно собирать docker images:

    - контейнер gitlab-runner д.б. запущен с опцией `--privileged`

    - в файл конфигурационный файл runner вписать что он работает в привилигированном режиме

      https://docs.gitlab.com/runner/executors/docker.html#use-docker-in-docker-with-privileged-mode

      ```bash
      nano /srv/gitlab-runner/config/config.toml
      ------
      [[runners]]
        name = "my-runner"
        url = "http://35.205.50.178/"
        executor = "docker"
        ...
        [runners.docker]
          ...
          privileged = true
          ...
      ------
      ```



  - Регистрируем Runner

    ```bash
    ssh appuser@35.205.50.178 -i ~/.ssh/appuser

    docker exec -it gitlab-runner gitlab-runner register --run-untagged --locked=false
    ```

    При регистрации указываем

    ```properties
    Runtime platform                                    arch=amd64 os=linux pid=11 revision=5a147c92 version=11.11.1
    Running in system-mode.

    Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
    http://35.205.50.178/
    Please enter the gitlab-ci token for this runner:
    токен, который запомнили выше
    Please enter the gitlab-ci description for this runner:
    [id_xxxxx8d2xxxxx]: my-runner
    Please enter the gitlab-ci tags for this runner (comma separated):
    linux,xenial,ubuntu,docker
    Registering runner... succeeded                     runner=xxxxxxx
    Please enter the executor: virtualbox, shell, docker-windows, docker-ssh, parallels, ssh, docker+machine, docker-ssh+machine, kubernetes, docker:
    docker
    Please enter the default Docker image (e.g. ruby:2.1):
    alpine:latest
    Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!

    ```

    В этом разделе увидим зарегистрированный Runner


- Переходим в раздел пайплайнов CI/CD, наш простой пайплайн теперь имеет статус `passed`

## Тестируем приложение

- Добавляем его в репозиторий и пушим в GitLAB (Add reddit app)

  ```bash
  git clone https://github.com/express42/reddit.git
  rm -rf ./reddit/.git
  ```

- Скорректировали файл `.gitlab-ci.yml` под приложение reddit, добавили указанный в пайплайне скрипт руби `reddit/simpletest.rb`, добавили библиотеку `gem 'rack-test'` в `reddit/Gemfile` (не знаю, зачем, не объясняется)

- После проделанных мероприятий на каждое изменение будет запускаться тест

- Пушим, смотрим на job `test_unit_job` (т.к. по сути только его и настроили пока, в остальных джобах просто указано `echo`)

- Добавили dev-окружение в pipeline, в задание deploy_dev_job (тестирование выполняется последнего коммита)

  ```yaml
    environment:
      name: dev
      url: http://dev.example.com
  ```

  После успешного теста в интерфейсе Gitlab в разделе Operations->Environments появится добавленное окружение `dev` с ссылкой

- Добавили еще 2 окружения `stage ` и `production ` с возможностью запуска по кнопке и при наличии teg'а определенного формата (например, 2.4.10). При отсутствии тега этих шагов в интерфейсе теста pipeline в GitLAB не будет.

  ```yaml
  production:
    stage: production
    when: manual
    only:
      - /^\d+\.\d+\.\d+/
    script:
      - echo 'Deploy'
    environment:
      name: production
      url: https://example.co
  ```

- Добавили динамическое окружение для каждого бранча

  ```bash
  branch review:
    stage: review
    script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
    environment:
      name: branch/$CI_COMMIT_REF_NAME
      url: http://$CI_ENVIRONMENT_SLUG.example.com
    only:
      - branches
    except:
      - master
  ```

  Пригодится:

  Описание переменных CI https://docs.gitlab.com/ee/ci/variables/predefined_variables.html

  Некоторое раскрытие работы используемых переменных CI https://docs.gitlab.com/ee/ci/environments.html#example-configuration



## Задание со * (стр 48)

- Внутри проекта `example`создаем секреты для доступа на DockerHub в разделе Settings > CI / CD > Variables

- Корректируем задание build_job в pipeline этапа build  в `mnsold-otus_microservices\.gitlab-ci.yml`

  Имидж в котором будет происходить сборка должен содержать все необходимые команды (инструменты) в инструкции `script:`, поэтому в инструкции `image:` конкретного этого этапа указываем имидж `docker:stable` (или указать свой со всеми необходимыми командами).

  Директива `before_script: []` внутри этапа позволит переопределить before_script объявленный на уровне pipeline.

  Пригодится!

  Деплой через ssh https://medium.com/@codingfriend/continuous-integration-and-deployment-with-gitlab-docker-compose-and-digitalocean-6bd6196b502a

  Документация на опции GitLab CI/CD Pipeline в .gitlab-ci.yml https://docs.gitlab.com/ee/ci/yaml/

  Некоторые разъяснения в документации по использованию имиджей докера и инструкции `services:` https://docs.gitlab.com/ee/ci/docker/using_docker_images.html#what-is-a-service

  Докер в докере и наличие для этого сервиса `docker:dind` :

  1) http://qaru.site/questions/2440757/role-of-docker-in-docker-dind-service-in-gitlab-ci

  2) https://docs.gitlab.com/ce/ci/docker/using_docker_build.html#use-docker-in-docker-executor

  Докер в докере и привилегированный режим (контейнер gitlab-runner д.б. запущен с опцией `--privileged`) https://docs.gitlab.com/runner/executors/docker.html#use-docker-in-docker-with-privileged-mode


- Подготавливаем выделенный сервер для деплоя с автоматической установкой докера

  ```bash
  cd gitlab-infra/terraform/stage
  terraform init
  terraform apply
  ```

- Настраиваем Gitlab для выполнения деплоя через ssh

  Для этого создаем переменные в настройках проекта CI

  - переменную `CI_PRIVATE_KEY` с приватным ключом аналогичным `~/.ssh/appuser`
  - переменную `CI_USER` с именем пользователя
  - переменную `HOST` с IP адресом выделенного сервера

- Корректируем задание deploy_dev_job в pipeline этапа review в `mnsold-otus_microservices\.gitlab-ci.yml`

- Для проверки перейти по адресу http://IP_GCP:9292 (или нажать кнопку " View deployment" в Environments в разделе Operations проекта)


## Задание со * (стр 49)

- Автоматизация развертывания и регистрации Gitlab CI Runner

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

- Интеграция Pipeline с тестовым Slack чатом

  - В настройках проекта, разделе Integration, идем в сервис "Slack notifications"
  - Согласно предложению сервиса "Slack notifications" выполнить настройку по добавлению webhook (Add an incoming webhook), делаем это, переходим по предоставленной GitLab ссылке, добавляем конфигурацию,  выбираем канал уведомления
  - Меняем имя уведомления в поле Customize Name на Gitlab (вместо incoming-webhook)
  - Копируем полученный Webhook URL вида `https://hooks.slack.com/services/T6Hxxxxxx/...` , вставляем в сервис "Slack notifications" в поле Webhook
  - Жмем тест конфигурации, в канал прилетает уведомление
  - Активируем сервис "Slack notifications"

  Канал интеграции слаки https://devops-team-otus.slack.com/messages/CH2FT5W87
