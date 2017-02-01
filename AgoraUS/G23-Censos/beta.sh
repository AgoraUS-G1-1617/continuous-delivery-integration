#!/bin/bash 

ENV_NAME="AgoraUS-G23-Censos"
URL_VIRTUAL_HOST="beta.censos.agoraus1.egc.duckdns.org"
BRANCH="beta"
PROJECT_JENKINS_NAME="AgoraUS-G23-Censos_make"

PATH_ROOT="/var/jenkins_home"
PATH_ROOT_HOST="/home/egcuser/jenkins_home"

CONF_TOMCAT_SERVER="$PATH_ROOT_HOST/continuous-delivery-playground/AgoraUS/G23-Censos/beta-conf/tomcat7/server.xml"

MYSQL_PROJECT_ROUTE="localhost"
MYSQL_ROOT_PASSWORD="$(date +%s | sha256sum | base64 | head -c 32)"


echo "Eliminando contenedores antiguos"

ContainerId1=`docker ps -qa --filter "name=$ENV_NAME-$BRANCH-mysql"`
if [ -n "$ContainerId1" ]
then
	echo "Stopping and removing existing $ENV_NAME-$BRANCH-mysql container"
	docker stop $ContainerId1
	docker rm -v $ContainerId1
fi

ContainerId2=`docker ps -qa --filter "name=$ENV_NAME-$BRANCH-tomcat"`
if [ -n "$ContainerId2" ]
then
	echo "Stopping and removing existing $ENV_NAME-$BRANCH-tomcat container"
	docker stop $ContainerId2
	docker rm -v $ContainerId2
fi


echo "Preparando archivos para despliegue"

rm -r "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/"

mkdir -p "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/webapps/"

# WAR
find "$PATH_ROOT/jobs/$PROJECT_JENKINS_NAME/lastSuccessful/" -follow -name *.war -exec cp {} "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/webapps/" \;
mv $PATH_ROOT/deploys/$ENV_NAME/$BRANCH/webapps/*.war $PATH_ROOT/deploys/$ENV_NAME/$BRANCH/webapps/ROOT.war

# SQL -> "jobs/test31/builds/lastSuccessfulBuild/archive/DeliberationsScript.sql"
find "$PATH_ROOT/jobs/$PROJECT_JENKINS_NAME/lastSuccessful/archive/" -follow -name *.sql -exec cp {} "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/" \;
mv $PATH_ROOT/deploys/$ENV_NAME/$BRANCH/*.sql $PATH_ROOT/deploys/$ENV_NAME/$BRANCH/populate.sql


echo "Desplegando contenedores para $ENV_NAME"

docker run --name $ENV_NAME-$BRANCH-mysql \
    -v "$PATH_ROOT_HOST/deploys/$ENV_NAME/$BRANCH/populate.sql":/home/user/populate.sql \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    --restart=always \
    -d mysql:5.7 \
    --bind-address=0.0.0.0


echo "$ENV_NAME-mysql creado !"
# echo "$ENV_NAME-mysql creado ($MYSQL_ROOT_PASSWORD)!"

sleep 30

docker exec $ENV_NAME-$BRANCH-mysql \
    bash -c "exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < /home/user/populate.sql"

echo "$ENV_NAME-mysql populado !"

sleep 20

docker restart $ENV_NAME-$BRANCH-mysql

sleep 5

docker run -d --name $ENV_NAME-$BRANCH-tomcat \
    --link $ENV_NAME-$BRANCH-mysql:$MYSQL_PROJECT_ROUTE \
    -v "$PATH_ROOT_HOST/deploys/$ENV_NAME/$BRANCH/webapps/":/usr/local/tomcat/webapps \
    -v "$CONF_TOMCAT_SERVER":/usr/local/tomcat/conf/server.xml \
    --add-host beta.autha.agoraus1.egc.duckdns.org:192.168.20.84 \
    --add-host autha.agoraus1.egc.duckdns.org:192.168.20.84 \
    --add-host beta.authb.agoraus1.egc.duckdns.org:192.168.20.84 \
    --add-host authb.agoraus1.egc.duckdns.org:192.168.20.84 \
    --add-host recuento.agoraus1.egc.duckdns.org:192.168.20.84 \
    --add-host beta.recuento.agoraus1.egc.duckdns.org:192.168.20.84 \
    --restart=always \
    -e VIRTUAL_HOST="$URL_VIRTUAL_HOST" \
    -e VIRTUAL_PORT=8080 \
    -e "LETSENCRYPT_HOST=$URL_VIRTUAL_HOST" \
    -e "LETSENCRYPT_EMAIL=annonymous@alum.us.es" \
    tomcat:7

#    -e "LETSENCRYPT_HOST=$URL_VIRTUAL_HOST" \
#    -e "LETSENCRYPT_EMAIL=annonymous@alum.us.es" \
#    -e VIRTUAL_PROTO=https \

echo "Aplicación desplegada en https://$URL_VIRTUAL_HOST"
