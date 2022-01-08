# Docker Delivery-ready appliance

## Overview

Current appliance provides docker-compose service stack for ruby 3.10 and node.js LTS(currently 16.0). Main goal is to use docker original tools without using of shell scripting and additional software.

> Current appliance implements development, testing, building environment for next delivery scheme:

| Stage #:      | Stage         | Stage 2    | Stage 3    | Stage 4      |
|---------------|---------------|------------|------------|--------------|
| **Behavior:** | _Runnable_    | _Runnable_ | _Runnable_ | _Deployable_ |
| **Stage:**    | Development   | Test       | Staging    | Production   |
| **Image tag** | **dev**       | **test**   | **stage**  | **latest**   |

> Appliance builds image and service for **every** stage. As example if thereis application of two parts: **backend** and **frontend**, then as result we are will have:
  * 8 sets of application images, containers and services
  * 1 postgresql database service
  * 1 redis key-value store service

```shell
  NAME                                         COMMAND                  SERVICE             STATUS              PORTS
docker_delivery_appliance-backend-dev-1      "sbin backend_dev"       backend-dev         created             
docker_delivery_appliance-backend-prod-1     "sbin backend_prod"      backend-prod        created             
docker_delivery_appliance-backend-stage-1    "sbin backend_prod"      backend-stage       created             
docker_delivery_appliance-backend-test-1     "sbin backend_test"      backend-test        created             
docker_delivery_appliance-frontend-dev-1     "sbin frontend_dev"      frontend-dev        created             
docker_delivery_appliance-frontend-prod-1    "sbin frontend_prod"     frontend-prod       created             
docker_delivery_appliance-frontend-stage-1   "sbin frontend_prod"     frontend-stage      created             
docker_delivery_appliance-frontend-test-1    "sbin frontend_test"     frontend-test       created             
docker_delivery_appliance-postgres-1         "docker-entrypoint.s…"   postgres            exited (1)          
docker_delivery_appliance-redis-1            "docker-entrypoint.s…"   redis               running             6379/tcp

```

> Each Stage connected to the own network. So implemented 4 networks: **dev**, **test**, **stage**, **prod**.

> Database services connected to all networks, so every environments stored inside one database instance.

> Service for production environment present to simplify building of the production-ready deliverable image, set **latest** tag and other required labels. But it is not a good idea to run it at development machine.

## Requirements
- docker
- docker-compose

## Installation

```
$ git clone https://github.com/sbezugliy/docker_delivery_appliance.git
$ cd docker_delivery_appliance
$ cp <your ruby backend app folder> ./apps/backend
$ cp <your node-js frontend app folder> ./apps/backend
```
## Configuring
### Customizing services stack
To exclude some services or stage from the stack just comment out or remove section at the docker-compose.yml file, as the example(excluding 'frontend staging'):

```YAML
version: "3.9"
services:
# ...
#  frontend-stage:
#    extends:
#      file: ./docker-appliance/services/stage.yml
#      service: frontend
#    depends_on:
#      - backend-stage
#      - redis
  backend-stage:
    extends:
      file: ./docker-appliance/services/stage.yml
      service: backend
    depends_on:
      - postgres
      - redis
# ...
```

### Application
* Copy ruby backend application to the `./apps/backend`
* Copy node.js application to the `./apps/frontend`

### Environment variables
Configure environment variables of each stage and service.

Environment variables defined inside of env files at next paths:\
* `./env/frontend/<stage_name>.env`
* `./env/backend/<stage_name>.env`
* `./env/databases/<database_service_name>.env`

> Environment files of databases are common with backend services.

### Dockerfiles of the services
Fill out Docker files with required actions to build application

Dockerfiles are here `./dockerfiles/<app_part_name>.Dockerfile`

> To exclude some files from docker processing scope use dockerignore files: `./dockerfiles/<app_part_name>.Dockerfile.dockerignore`

>Don't forget that you are working under docker context wich moved to the application directory.

### Entrypoints
Replace or create entrypoint scripts of the container.
> Scripts of entrypoints of applications present at the next path:\
`./sbin/<service_name>_<stage_name>`docker-appliance/services/development.yml

### Configure network port mapping at the ./services/<stage>.yml




As example exposing port for backend development, at the file `docker-appliance/services/development.yml`:

```YAML
---
services:
  frontend:
    image: frontend:dev
    env_file:
      - ../env/frontend/development.env
    build:
      context: ../../apps/frontend/
      dockerfile: ../dockerfiles/frontend.Dockerfile
      target: development
    entrypoint: ["sbin", "frontend_dev"]
    networks:
      - dev
  backend:
    image: backend:dev
    env_file:
      - ../env/backend/development.env
      - ../env/databases/postgres.env
      - ../env/databases/redis.env
    ports:
      - 80:3000 # <-- EXPOSED PORTS
    build:
      context: ../../apps/backend/
      dockerfile: ../dockerfiles/backend.Dockerfile
      target: development
    entrypoint: ["sbin", "backend_dev"]
    networks:
      - dev

```

### Running

```
$ docker-compose up
```
