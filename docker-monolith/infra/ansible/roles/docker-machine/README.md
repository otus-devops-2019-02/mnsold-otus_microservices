# Ansible Role: Docker-machine

## Переменные роли

Доступные переменный и их умолчания указаны в `defaults/main.yml`

Docker Machine опции установки:

    docker_install_machine: true
    docker_compose_version: "v0.16.0"
    docker_machine_path: /usr/local/bin/docker-machine

## Пример playbook

```yaml
- hosts: all
  roles:
    - docker-machine
```
