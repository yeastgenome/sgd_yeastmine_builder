#!/bin/bash

set -e

mkdir /root/.intermine
cd /root/

# Empty log
echo "" > /root/build.progress

# Build InterMine if any of the envvars are specified.
if [ ! -z ${IM_REPO_URL} ] || [ ! -z ${IM_REPO_BRANCH} ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Start InterMine build" #>> /home/intermine/intermine/build.progress
    echo "$(date +%Y/%m/%d-%H:%M) Cloning ${IM_REPO_URL:-https://github.com/intermine/intermine} branch ${IM_REPO_BRANCH:-master} for InterMine build" #>> /home/intermine/intermine/build.progress
    git clone ${IM_REPO_URL:-https://github.com/intermine/intermine} intermine --single-branch --branch ${IM_REPO_BRANCH:-master} --depth=1

    cd intermine

    (cd plugin && ./gradlew clean && ./gradlew install) &&
    (cd intermine && ./gradlew clean && ./gradlew install) &&
    (cd bio && ./gradlew clean && ./gradlew install) &&
    (cd bio/sources && ./gradlew clean && ./gradlew install) &&
    (cd bio/postprocess/ && ./gradlew clean && ./gradlew install)

    # Read the version numbers of the built InterMine, as we'll need to set
    # the mine to use the same versions for it to use the local build.
    IM_VERSION=$(sed -n "s/^\s*version.*\+'\(.*\)'\s*$/\1/p" intermine/build.gradle)
    BIO_VERSION=$(sed -n "s/^\s*version.*\+'\(.*\)'\s*$/\1/p" bio/build.gradle)

    cd /root/
fi

echo "Starting mine build"
echo $MINE_REPO_URL
# Check if mine exists and is not empty
if [ -d ${MINE_NAME:-biotestmine} ] && [ ! -z "$(ls -A ${MINE_NAME:-biotestmine})" ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Update ${MINE_NAME:-biotestmine} to newest version" #>> /home/intermine/intermine/build.progress
    cd ${MINE_NAME:-biotestmine}
    # git pull
    cd /root/
else
    echo "$(date +%Y/%m/%d-%H:%M) Clone ${MINE_NAME:-biotestmine}  \nSOLR_HOST\t$SOLR_HOST\nTOMCAT_HOST\t$TOMCAT_HOST\n"
    git clone ${MINE_REPO_URL:-https://github.com/intermine/biotestmine} ${MINE_NAME:-biotestmine}
    echo "$(date +%Y/%m/%d-%H:%M) Update keyword_search.properties to use http://solr" #>> /home/intermine/intermine/build.progress
    sed -i 's/localhost/'${SOLR_HOST:-solr}'/g' ./${MINE_NAME:-biotestmine}/dbmodel/resources/keyword_search.properties
    sed -i 's/localhost/'${SOLR_HOST:-solr}'/g' ./${MINE_NAME:-biotestmine}/dbmodel/resources/objectstoresummary.config.properties
fi

# If InterMine or Bio versions have been set (likely because of a custom
# InterMine build), update gradle.properties in the mine.
if [ ! -z ${IM_VERSION} ]; then
    sed -i "s/\(systemProp\.imVersion=\).*\$/\1${IM_VERSION}/" /root/${MINE_NAME:-biotestmine}/gradle.properties
fi
if [ ! -z ${BIO_VERSION} ]; then
    sed -i "s/\(systemProp\.bioVersion=\).*\$/\1${BIO_VERSION}/" /root/${MINE_NAME:-biotestmine}/gradle.properties
fi

# clone bio sources repo if url is given
if [ ! -z "$BIOSOURCES_REPO_URL" ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Clone ${BIOSOURCES_REPO_URL}"
    git clone ${BIOSOURCES_REPO_URL} $MINE_NAME-bio-sources
    # build and install bio sources
    cd /root/$MINE_NAME-bio-sources
    echo "$(date +%Y/%m/%d-%H:%M) Building and Installing bio sources"
    ./gradlew clean --stacktrace
    ./gradlew install --stacktrace
    cd /root
fi

# Copy project_build from intermine_scripts repo
if [ ! -f /root/${MINE_NAME:-biotestmine}/project_build ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Cloning intermine scripts repo to /home/intermine/intermine/intermine-scripts"
    git clone https://github.com/intermine/intermine-scripts
    echo "$(date +%Y/%m/%d-%H:%M) Copy project_build to /home/intermine/intermine/${MINE_NAME:-biotestmine}"
    cp /root/intermine-scripts/project_build /root/${MINE_NAME:-biotestmine}/project_build
    chmod +x /root/${MINE_NAME:-biotestmine}/project_build
fi

# Copy mine properties
if [ ! -f /root/.intermine/${MINE_NAME:-biotestmine}.properties ]; then
        echo "$(date +%Y/%m/%d-%H:%M) Copy ${MINE_NAME:-biotestmine}.properties to ~/.intermine/${MINE_NAME:-biotestmine}.properties"
        cp /root/yeastmine/${MINE_NAME:-biotestmine}.properties /root/.intermine/
    echo -e "$(date +%Y/%m/%d-%H:%M) Set properties in .intermine/${MINE_NAME:-biotestmine}.properties to\nPSQL_DB_NAME\tbiotestmine\nINTERMINE_PGUSER\t$INTERMINE_PGUSER\nINTERMINE_PGPASSWORD\t$INTERMINE_PGPASSWORD\nTOMCAT_USER\t$TOMCAT_USER\nTOMCAT_PWD\t$TOMCAT_PWD\nGRADLE_OPTS\t$GRADLE_OPTS" #>> /home/intermine/intermine/build.progress

    sed -i "s/PSQL_DB_NAME/${MINE_NAME:-biotestmine}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/INTERMINE_PSQL_USER/${INTERMINE_PGUSER:-postgres}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/INTERMINE_PSQL_PWD/${INTERMINE_PGPASSWORD:-postgres}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/SPELL_USER/${SPELL_USER:-speller}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/SPELL_PWD/${SPELL_PWD:-password}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/SGD_USER/${SGD_USER:-speller}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/SGD_PWD/${SGD_PWD:-password}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/TOMCAT_USER/${TOMCAT_USER:-tomcat}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/TOMCAT_PWD/${TOMCAT_PWD:-tomcat}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/webapp.deploy.url=http:\/\/localhost:8080/webapp.deploy.url=http:\/\/${TOMCAT_HOST:-tomcat}:${TOMCAT_PORT:-8080}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/webapp.baseurl=http:\/\/localhost:8080/webapp.baseurl=http:\/\/${TOMCAT_HOST:-tomcat}:${TOMCAT_PORT:-8080}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/project.sitePrefix=http:\/\/localhost:8080/project.sitePrefix=http:\/\/${TOMCAT_HOST:-tomcat}:${TOMCAT_PORT:-8080}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/project.releaseVersion=Beta/project.releaseVersion=1.0.0/" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/serverName=INTERMINE_PGHOST/serverName=${INTERMINE_PGHOST:-postgres}:${INTERMINE_PGPORT:-5432}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/serverName=SPELL_HOST/serverName=${SPELL_HOST:-host}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
    sed -i "s/serverName=SGD_HOST/serverName=${SGD_HOST:-host}/g" /root/.intermine/${MINE_NAME:-biotestmine}.properties
fi

# Copy mine configs
if [ ! -f /root/${MINE_NAME:-biotestmine}/project.xml ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Set correct source path in alliance else ***** project.xml"
    sed -i 's/dump="true"/dump="false"/g' /root/${MINE_NAME:-biotestmine}/project.xml
fi

cd ${MINE_NAME:-biotestmine}

echo "$(date +%Y/%m/%d-%H:%M) Running project_build script"
./project_build -b -T localhost /root/dump/dump

#echo "$(date +%Y/%m/%d-%H:%M) Gradle: build userDB" #>> /home/intermine/intermine/build.progress
#./gradlew buildUserDB --stacktrace #>> /home/intermine/intermine/build.progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: build webapp" #>> /home/intermine/intermine/build.progress
./gradlew cargoRedeployRemote  --stacktrace #>> /home/intermine/intermine/build.progress
sleep 60
./gradlew cargoRedeployRemote  --stacktrace #>> /home/intermine/intermine/build.progress
