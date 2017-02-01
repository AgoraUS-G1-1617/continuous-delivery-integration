#!/bin/bash

ENV_NAME="AgoraUS-G7-AutenticacionA"
URL_VIRTUAL_HOST="beta.autha.agoraus1.egc.duckdns.org"
BRANCH="beta"
PROJECT_JENKINS_NAME="AgoraUS-G7-AutenticacionA_make"

PATH_ROOT="/var/jenkins_home"
PATH_ROOT_HOST="/home/egcuser/jenkins_home"

MYSQL_PROJECT_ROUTE="exdb"
MYSQL_ROOT_PASSWORD="$(date +%s | sha256sum | base64 | head -c 32)"

echo "Eliminando contenedores antiguos"

ContainerId1=`docker ps -qa --filter "name=$ENV_NAME-$BRANCH-mysql"`
if [ -n "$ContainerId1" ]
then
	echo "Stopping and removing existing $ENV_NAME-$BRANCH-mysql container"
	docker stop $ContainerId1
	docker rm -v $ContainerId1
fi

ContainerId2=`docker ps -qa --filter "name=$ENV_NAME-$BRANCH-php"`
if [ -n "$ContainerId2" ]
then
	echo "Stopping and removing existing $ENV_NAME-$BRANCH-php container"
	docker stop $ContainerId2
	docker rm -v $ContainerId2
fi


echo "Preparando archivos para despliegue"

rm -r "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/"

mkdir -p "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/"

# PROYECT FOLDER
cp -r $PATH_ROOT/builds/$PROJECT_JENKINS_NAME/* $PATH_ROOT/deploys/$ENV_NAME/$BRANCH/

# Variables files
cp -f $PATH_ROOT/continuous-delivery-playground/AgoraUS/G7-AutenticacionA/beta-conf/variables.php $PATH_ROOT/deploys/$ENV_NAME/$BRANCH/auth/variables.php

echo "Desplegando contenedores para $ENV_NAME"

docker run --name $ENV_NAME-$BRANCH-mysql \
    -v "$PATH_ROOT_HOST/deploys/$ENV_NAME/$BRANCH/auth/auth_DB_script.sql":/home/user/populate.sql \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    --restart=always \
    -d mysql:5.7 \
    --bind-address=0.0.0.0


echo "$ENV_NAME-mysql creado !"
# echo "$ENV_NAME-mysql creado ($MYSQL_ROOT_PASSWORD)!"

sleep 20

docker exec $ENV_NAME-$BRANCH-mysql \
    bash -c "exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < /home/user/populate.sql"

echo "$ENV_NAME-mysql populado !"

sleep 20

docker restart $ENV_NAME-$BRANCH-mysql

sleep 5

docker run -d --name $ENV_NAME-$BRANCH-php \
	--link $ENV_NAME-$BRANCH-mysql:$MYSQL_PROJECT_ROUTE \
	-v "$PATH_ROOT_HOST/deploys/$ENV_NAME/$BRANCH/auth/":/home/auth/ \
	-e WEB_DOCUMENT_ROOT=/home/auth \
	--restart=always \
	-e VIRTUAL_HOST="$URL_VIRTUAL_HOST" \
	-e VIRTUAL_PORT=80 \
	-e "LETSENCRYPT_HOST=$URL_VIRTUAL_HOST" \
	-e "LETSENCRYPT_EMAIL=annonymous@alum.us.es" \
	-c "a2enmod rewrite" \
	webdevops/php-nginx:debian-8


echo "Aplicación desplegada en https://$URL_VIRTUAL_HOST"
