#!/bin/bash
export MSYS_NO_PATHCONV=1
set -e

S2I_EXE=s2i
if [ -z $(type -P "$S2I_EXE") ]; then
  echo -e "The ${S2I_EXE} executable is needed and not on your path."
  echo -e "It can be downloaded from here: https://github.com/openshift/source-to-image"
  echo -e "Make sure you place it in a directory on your path."
  exit 1
fi

SCRIPT_HOME="$( cd "$( dirname "$0" )" && pwd )"
export COMPOSE_PROJECT_NAME="fpo"

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF

  Usage: $0 {start|stop|build|rm}

  Options:

  build - Build the docker images for the project.
          You need to do this first, since the builds require
          a combination of Docker and S2I builds.

  start - Creates the application containers from the built images
          and starts the services based on the docker-compose.yml file.

          You can pass in a list of containers to start.  
          By default all containers will be started.
          
          The API_URL used by fpo-web can also be redirected.

          Examples:
          $0 start
          $0 start fpo-web
          $0 start fpo-web API_URL=http://docker.for.win.localhost:56325/api/v1

  stop - Stops the services.  This is a non-destructive process.  The containers
         are not deleted so they will be reused the next time you run start.

  rm - Removes any existing application containers.

  build-api - Build the API server only.
EOF
exit 1
}
# -----------------------------------------------------------------------------------------------------------------
# Default Settings:
# -----------------------------------------------------------------------------------------------------------------
DEFAULT_CONTAINERS="fpo-db fpo-api schema-spy fpo-web"
# -----------------------------------------------------------------------------------------------------------------
# Functions:
# -----------------------------------------------------------------------------------------------------------------
build-web() {
  #
  # fpo-web
  #
  echo -e "\nBuilding angular-builder image ..."
  docker build \
    -t 'angular-builder' \
    -f '../fpo-web/openshift/templates/angular-builder/Dockerfile' '../fpo-web/openshift/templates/angular-builder/'

  echo -e "\nBuilding nginx-runtime image ..."
  docker build \
    -t 'nginx-runtime' \
    -f '../fpo-web/openshift/templates/nginx-runtime/Dockerfile' '../fpo-web/openshift/templates/nginx-runtime/'

  echo -e "\nBuilding angular-on-nginx image ..."
  ${S2I_EXE} build \
    '../fpo-web' \
    'angular-builder' \
    'angular-on-nginx' \
    --runtime-image \
    "nginx-runtime" \
    -a "/opt/app-root/src/dist/:app"
}

build-db() {
  #
  # fpo-db
  #
  # Nothing to build here ...
  echo
}

build-schema-spy() {
  #
  # schema-spy
  #
  echo -e "\nBuilding schema-spy image ..."
  docker build \
    https://github.com/bcgov/SchemaSpy.git \
    -t 'schema-spy'
}

build-api() {
  #
  # fpo-api
  #
  echo -e "\nBuilding django image ..."
  ${S2I_EXE} build \
    '../fpo-api' \
    'centos/python-36-centos7' \
    'django'
}

buildImages() {
  build-web
  build-db
  build-schema-spy
  build-api
}

configureEnvironment () {
  for arg in $@; do
    case "$arg" in
      *=*)
        export ${arg}
        ;;  
    esac
  done
  
  # fpo-db
  export POSTGRESQL_DATABASE="FAMILY_PROTECTION_ORDER"
  export POSTGRESQL_USER="DB_USER"
  export POSTGRESQL_PASSWORD="DB_PASSWORD"

  # schema-spy
  export DATABASE_SERVICE_NAME="fpo-db"
  export POSTGRESQL_DATABASE=${POSTGRESQL_DATABASE}
  export POSTGRESQL_USER=${POSTGRESQL_USER}
  export POSTGRESQL_PASSWORD=${POSTGRESQL_PASSWORD}

  # fpo-api
  export API_HTTP_PORT=${API_HTTP_PORT-8081}
  export DATABASE_SERVICE_NAME="fpo-db"
  export DATABASE_ENGINE="postgresql"
  export DATABASE_NAME=${POSTGRESQL_DATABASE}
  export DATABASE_USER=${POSTGRESQL_USER}
  export DATABASE_PASSWORD=${POSTGRESQL_PASSWORD}
  export DJANGO_SECRET_KEY=wpn1GZrouOryH2FshRrpVHcEhMfMLtmTWMC2K5Vhx8MAi74H5y
  export DJANGO_DEBUG=True

  # fpo-web
  export WEB_HTTP_PORT=${WEB_HTTP_PORT-8080}
  export API_URL=${API_URL-http://fpo-api:8080/api/v1/}
  export IpFilterRules='#allow all; deny all;'
  export RealIpFrom='127.0.0.0/16'
}

getStartupParams() {
  CONTAINERS=""
  ARGS="--force-recreate"

  for arg in $@; do
    case "$arg" in
      *=*)
        # Skip it
        ;;  
     -*)
        ARGS+=" $arg";;
      *)
        CONTAINERS+=" $arg";;
    esac
  done

  if [ -z "$CONTAINERS" ]; then
    CONTAINERS="$DEFAULT_CONTAINERS"
  fi

  echo ${ARGS} ${CONTAINERS}
}
# =================================================================================================================

pushd ${SCRIPT_HOME} >/dev/null

case "$1" in
  start)
    shift
    _startupParams=$(getStartupParams $@)
    configureEnvironment $@
    docker-compose up ${_startupParams}
    ;;
  stop)
    configureEnvironment
    docker-compose stop
    ;;
  rm)
    configureEnvironment
    docker-compose rm
    ;;
  build)
    buildImages
    ;;
  build-api)
    build-api
    ;;
  *)
    usage
esac

popd >/dev/null
