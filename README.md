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