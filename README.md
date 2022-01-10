# Docker Delivery-ready appliance

Contents\

[1. Overview](#1-overview)

[1.1 Environment](#11-environment)

[1.2. Image runtime environments](#12-image-runtime-environments)

[1.2.1 Backend images](#121-backend-images)

[1.2.2 Frontend images](#122-frontend-images)

[2. Requirements](#2-requirements)

[3. Installation](#3-installation)

[4. Configuration](#4-configuration)

[4.1. Customization of services](#41-customization-of-services)

[4.2. Copy files of application services](#42-copy-files-of-application-services)

[4.3. Define environment variables](#43-define-environment-variables)

[4.3.1. Databases](#431-databases)

[4.3.1.1 PostgreSQL](#4311-postgresql)

[4.3.1.2 Redis](#4312-redis)

[4.3.2. Frontend](#432-frontend)

[4.3.3. Backend](#433-backend)

[4.4. Complete Dockerfiles](#44-complete-dockerfiles)

[4.5. Complete startup action at entrypoint scripts](#45-complete-startup-actions-at-entrypoint-scripts)

[4.6. Configure network port mapping of services](#46-complete-network-port-mapping-of-services)

[5. Build images and service stack](#5-build_images_and_service_stack)

[6. Running services](#6-running_services)

[7. Deliver images to the docker registry](#7-deliver-images-to-the-docker-registry)

[8. Deployment](#8-deployment)

[8.1. Docker Swarm Cluster](#81-docker-swarm-cluster)

[8.2. Kubernetes Cluster](#82-kubernetes-cluster)

[8.3. Docker Swarm Cluster in the Kubernetes mode](#83-docker-swarm-cluster-in-the-kubernetes-mode)

## 1. Overview
### 1.1 Environment
Current appliance provides docker-compose service stack for ruby 3.10 and node.js LTS(currently 16.0).

> Current appliance implements development, testing, building environment for next delivery scheme:

| Stage #:         | Stage 1     | Stage 2    | Stage 3    | Stage 4      |
|------------------|-------------|------------|------------|--------------|
| **Behavior:**    | _Runnable_  | _Runnable_ | _Runnable_ | _Deployable_ |
| **Environment:** | Development | Test       | Staging    | Production   |
| **Image tag**    | **dev**     | **test**   | **stage**  | **latest**   |

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

> Database services are connected to all networks, so every environments stored inside one database instance.

> Service for production environment present to simplify building of the production-ready deliverable image, set **latest** tag and other required labels. But it is not a good idea to run it at development machine.

> Staging uses separate database, due to prodution database maybe too large for development machine. So if required to use data from production or similar layout define credentials of staging database from cloud providers, etc...
### 1.2. Image runtime environments
> Docker images for application services built as multi-stage images, which will be attached to the stack service by target mark:

#### 1.2.1. Backend runtime images
`/docker-appliance/dockerfiles/backend.Dockerfile`
```Dockerfile
# Base image target. Common build actions for each environment.
# There is used 3.1.0(currently latest) ruby version. To use earlier version,
# chang its value and rebuild service.
FROM ruby:3.1.0-alpine AS build_base

# ... Some actions

# Development target.
# Includes development application environment and tools.
# Volumes are attached as a local folders, accessible from the
# development host machine.
# Runs development server.
FROM build_base AS development

# ... Some actions

# Test target.
# Includes test application environment and tools.
# Volumes are attached as a local folders, accessible from the
# development host machine.
# Runs test suite in autotesting mode triggered by filechange watcher,
# also runs code linting before each test run.
FROM development AS test

# ... Some actions

# Staging -> Production target.
# Includes development application environment and tools.
# Assets are compiled and stored to public folder.
# Static code is compiled too and stored to folders for execution.
# Volumes contents copied to the image, codebase minimized, uglified, cleaned
# from development tools, debuggers, testing tools and other development
# artifacts.
# Secrets are hashed and all development environment variables removed
# or nullified. So, runtime environment variables should be provided
# from docker-swarm or kubernetes at boot time.
# Runs production server, which ready to receive connections from
# load-balancer or reverse proxy server.
FROM build_base AS production

# ... Some actions

```
#### 1.2.2. Frontend runtime images
> Similar scenario implemented for frontend image at `./docker-appliance/dockerfiles/frontend.Dockerfile

## 2. Requirements
- Docker
- Docker-compose
- Docker BuildKit

## 3. Installation

```
$ git clone https://github.com/sbezugliy/docker_delivery_appliance.git
$ cd docker_delivery_appliance
```
> Do actions from section **4. Configuring**

> Replace contents of a backend app at the `/contexts/backend/app`

> Replace contents of a frontend app at the `/contexts/frontend/app`

> Run required services as described at the section **6. Running services**

## 4. Configuring

### 4.1. Customization of services

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

### 4.2. Copy files of application services
* Review example applications at directories inside of `/contexts/<context_name>`. Pay attention to next points:
  * Development and test application environments starting-up using `guard` gem. Review `groups` and `guards` at the  `Guardfile`.
  * Review set of gems(`rspec` and plugins) for testing at the `Gemfile`.
  * Review set of gems(`rubocop` and styleguide plugins) for code quality checks and linting
  * Staging and production designed to work behind of load balancing proxy as `haproxy` or the reverse proxy, such as `nginx`. Do not forgot to configure required path mappings and streaming channels.
* Remove example applications and copy contents of yours:
  * Copy ruby backend application to the `/contexts/backend/app`
  * Copy node.js application to the `/contexts/frontend/app`
  * At the image build time container OS user will be switched to 1000:1000(or other non root user), so ownership of files will be changed to this user too.
* Review entrypoint and other system scripts at the `/contexts/<context_name>/sbin`
  * These scripts will be copied to the `/usr/local/sbin/` with executable permissions and ownership of root

### 4.3. Define environment variables
Rename `<environment>.env.example` files as `<environment>.env` at directories:
  * `/env/frontend/`
  * `/env/backend/`
  * `/env/databases/`

Change default values of environment variables for docker services, explanations are in the next sections. Also complete it using your custom variables.

#### 4.3.1. Databases

> * Environment files of databases are common with backend services. Be carefull  when sharing it with frontend.
> * Redis connection string better to define separately at the `frontend.env`. Review securing of redis database.
##### 4.3.1.1 PostgreSQL
  Initial database superuser credentials. Application database user/role will be created or altered(if exists) creates at the application boot time as one of first steps of the entrypoint script.
  >`/env/databases/postgres.env`
  ```sh
  POSTGRES_USER=postgres # Default postgress superuser
  POSTGRES_DB=postgres # Default system database name
  POSTGRES_PASSWORD=some_secure_secret_password # Secure superuser password
  ```
##### 4.3.1.2 Redis
  >`/env/databases/redis.env`
  ```
  ```
#### 4.3.2. Frontend
  >`/env/frontend/development.env`
  ```
  ```
  >`/env/frontend/test.env`
  ```
  ```
  >`/env/frontend/staging.env`
  ```
  ```
  >`/env/frontend/production.env`
  ```
  ```

#### 4.3.3. Backend
  >`/env/backend/development.env`
  ```
  ```
  >`/env/backend/test.env`
  ```
  ```
  >`/env/backend/staging.env`
  ```
  ```
  >`/env/backend/production.env`
  ```
  ```

### 4.4. Complete Dockerfiles
Fill out Docker files with required actions to build application

Dockerfiles are here `/docker-appliance/dockerfiles/<context_name>.Dockerfile`

> To exclude some files from docker processing scope use dockerignore files: `/docker-appliance/dockerfiles/<context_name>.Dockerfile.dockerignore`

> Don't forget, you are working inside of docker context and working directory moved to directory of this context.

### 4.5. Complete startup actions at entrypoint scripts
Replace or create entrypoint scripts of the container.
> Entrypoint scripts of applications present at the next path:\
`/contexts/<context_name>/sbin/<service_name>_<environment_name>`

### 4.6. Configure network port mapping of services
Path to service files is `/docker-appliance/services/<environment_name>.yml`

As example, exposing(mapping) TCP port of backend server from 3000 to 80 of the host, at the file\
`/docker-appliance/services/development.yml`:

```YAML
---
services:
  frontend:
    image: frontend:dev
    env_file:
      - ../env/frontend/development.env
    build:
      context: ../../contexts/frontend
      dockerfile: ../docker-appliance/dockerfiles/frontend.Dockerfile
      target: development
    entrypoint: "/usr/local/entrypoint"
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
      context: ../../contexts/backend/
      dockerfile: ../docker-appliance/dockerfiles/backend.Dockerfile
      target: development
    entrypoint: "/usr/local/entrypoint"
    networks:
      - dev

```

## 5. Build images and service stack

```
$ DOCKER_BUILDKIT=1 docker-compose build
```
> Only for development or QA machine. \
If you don't want to set env var each build time, then execute:\
`echo "export DOCKER_BUILDKIT=1" >> ~/.bashrc`\
_(replace `~/.bashrc` with name of rc file of your shell interpretter)_ \
Next, reload terminal session.

## 6. Running services

> Execute. Production services will not start, but may be rebuilt from staging image.


> Running whole stack
```
$ docker-compose up
```

### 6.1 Running development environment
> Running only development services
```
$ docker-compose up backend-dev frontend-dev
```

### 6.2 Execution tests and monitoring

> Execute test runs and attach consoles
```
$ docker-compose up backend-test frontend-test
```

> At the first console window:
```
$ docker-compose attach backend-test
```

> At the second console window:
```
$ docker-compose attach backend-test
```

## 7. Deliver images to the docker registry

## 8. Deployment

### 8.1. Docker Swarm Cluster

### 8.2. Kubernetes Cluster

### 8.3. Docker Swarm Cluster in the Kubernetes mode
