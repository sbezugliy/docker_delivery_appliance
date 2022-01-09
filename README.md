# Docker Delivery-ready appliance

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
`./docker-appliance/dockerfiles/backend.Dockerfile`
```Dockerfile
# Base image target. Common build actions for each environment.
# There is used 3.1.0(currently latest) ruby version. To use earlier version,
# chang its value and rebuild service.
FROM ruby:3.1.0-alpine AS build_base

# Development target.
# Includes development application environment and tools.
# Volumes are attached as a local folders, accessible from the
# development host machine.
# Runs development server.
FROM build_base AS development

# Test target.
# Includes test application environment and tools.
# Volumes are attached as a local folders, accessible from the
# development host machine.
# Runs test suite in autotesting mode triggered by filechange watcher,
# also runs code linting before each test run.
FROM development AS test

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

```
#### 1.2.2. Frontend runtime images
> Similar scenario implemented for frontend image at `./docker-appliance/dockerfiles/frontend.Dockerfile

## 2. Requirements
- docker
- docker-compose

## 3. Installation

```
$ git clone https://github.com/sbezugliy/docker_delivery_appliance.git
$ cd docker_delivery_appliance
$ cp <your ruby backend app folder> ./apps/backend
$ cp <your node-js frontend app folder> ./apps/backend
```
## 4. Configuring
### 4.1. Customizing services
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
* Review example applications at directories inside of `./apps/`. Pay attention to next points:
  * Development and test application environments starting-up using `guard` gem. Review `groups` and `guards` at the  `Guardfile`.
  * Review set of gems(`rspec` and plugins) for testing at the `Gemfile`.
  * Review set of gems(`rubocop` and styleguide plugins) for code quality checks and linting
  * Staging and production designed to work behind of load balancing proxy as `haproxy` or the reverse proxy, such as `nginx`. Do not forgot to configure required path mappings and streaming channels.
* Remove example applications and copy contents of yours:
  * Copy ruby backend application to the `./apps/backend/`
  * Copy node.js application to the `./apps/frontend/`

### 4.3. Define environment variables
Rename `<environment>.env.example` files as `<environment>.env` at directories:
  * `./env/frontend/`
  * `./env/backend/`
  * `./env/databases/`

Change default values of environment variables for docker services, explanations are in next sections. Also addict it with your values.

#### 4.3.1. Databases

> * Environment files of databases are common with backend services. Be carefull  when sharing it with frontend.
> * Redis connection string better to define separately at the `frontend.env`. Review securing of redis database.
##### 4.3.1.1 PostgreSQL
  Initial database superuser credentials. Credentials for application database user will be created in the appilcation image build time.
  >`./env/databases/postgres.env`
  ```sh
  POSTGRES_USER=postgres # Default postgress superuser
  POSTGRES_DB=postgres # Default system database name
  POSTGRES_PASSWORD=some_secure_secret_password # Secure superuser password
  ```
##### 4.3.1.2 Redis
  >`./env/databases/redis.env`
  ```
  ```
#### 4.3.2. Frontend
  >`./env/frontend/development.env`
  ```
  ```
  >`./env/frontend/test.env`
  ```
  ```
  >`./env/frontend/staging.env`
  ```
  ```
  >`./env/frontend/production.env`
  ```
  ```

#### 4.3.3. Backend
  >`./env/backend/development.env`
  ```
  ```
  >`./env/backend/test.env`
  ```
  ```
  >`./env/backend/staging.env`
  ```
  ```
  >`./env/backend/production.env`
  ```
  ```

### 4.4. Review and complete build actions at Dockerfiles of services
Fill out Docker files with required actions to build application

Dockerfiles are here `./dockerfiles/<app_part_name>.Dockerfile`

> To exclude some files from docker processing scope use dockerignore files: `./dockerfiles/<app_part_name>.Dockerfile.dockerignore`

>Don't forget that you are working inside of docker context and working directory moved to the application directory.

### 4.5. Complete startup actions at entrypoint scripts
Replace or create entrypoint scripts of the container.
> Entrypoint scripts of applications present at the next path:\
`./sbin/<service_name>_<stage_name>`

### 4.6. Configure network port mapping of services
Path to service files is `./services/<environment_name>.yml`

As example, exposing(mapping) TCP port of backend server from 3000 to 80 of the host, at the file\
`docker-appliance/services/development.yml`:

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

## 5. Running

Execute. Production services will not start, but may be rebuilt from staging image.

```
$ docker-compose up
```
