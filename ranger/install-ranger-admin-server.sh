#!/bin/bash
set -euo pipefail
set -x
export JAVA_HOME=/usr/lib/jvm/jre
# Define variables
hostname=`hostname -I | xargs`
installpath=/usr/lib/ranger
mysql_jar_location=http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.39/mysql-connector-java-5.1.39.jar
mysql_jar=mysql-connector-java-5.1.39.jar
ranger_version=$5
s3bucket_http_url=$6

# Database information
if [ -z "$7" ]; then
    db_host_address=locahost
    db_host_root_password=rangeradmin
else
    db_host_address=$7
    db_host_root_password=$8
fi

if [ "$ranger_version" == "1.0" ]; then
   ranger_s3bucket=$s3bucket_http_url/ranger/ranger-1.0.1
   ranger_admin_server=ranger-1.0.1-admin
   ranger_user_sync=ranger-1.0.1-usersync
elif [ "$ranger_version" == "0.7" ]; then
   ranger_s3bucket=$s3bucket_http_url/ranger/ranger-0.7.1
   ranger_admin_server=ranger-0.7.1-admin
   ranger_user_sync=ranger-0.7.1-usersync
elif [ "$ranger_version" == "0.6" ]; then
   ranger_s3bucket=$s3bucket_http_url/ranger/ranger-0.6.1
   ranger_admin_server=ranger-0.6.1-admin
   ranger_user_sync=ranger-0.6.1-usersync
else
   ranger_s3bucket=$s3bucket_http_url/ranger/ranger-0.5
   ranger_admin_server=ranger-0.5.3-admin
   ranger_user_sync=ranger-0.5.3-usersync
fi
ldap_ip_address=$1
ldap_server_url=ldap://$ldap_ip_address
ldap_base_dn=$2
ldap_bind_user_dn=$3
ldap_bind_password=$4
# Setup
yum install -y openldap openldap-clients openldap-servers
# Setup LDAP users
wget $s3bucket_http_url/inputdata/load-users-new.ldf
wget $s3bucket_http_url/inputdata/modify-users-new.ldf
wget $s3bucket_http_url/scripts/create-users-using-ldap.sh
chmod +x create-users-using-ldap.sh
./create-users-using-ldap.sh $ldap_ip_address
#Install mySQL
yum -y install mysql-server
service mysqld start
chkconfig mysqld on
mysqladmin -u root password rangeradmin || true
rm -rf $installpath
mkdir -p $installpath/hadoop
cd $installpath
wget $ranger_s3bucket/$ranger_admin_server.tar.gz
wget $ranger_s3bucket/$ranger_user_sync.tar.gz
wget $mysql_jar_location
wget $ranger_s3bucket/solr_for_audit_setup.tar.gz
#Update ranger admin install.properties
tar -xvf $ranger_admin_server.tar.gz
cd $ranger_admin_server
sudo sed -i "s|SQL_CONNECTOR_JAR=.*|SQL_CONNECTOR_JAR=$installpath/$mysql_jar|g" install.properties
sudo sed -i "s|db_host=.*|db_host=$db_host_address|g" install.properties
sudo sed -i "s|db_root_password=.*|db_root_password=$db_host_root_password|g" install.properties
sudo sed -i "s|db_password=.*|db_password=rangeradmin|g" install.properties
sudo sed -i "s|audit_db_password=.*|audit_db_password=rangerlogger|g" install.properties
sudo sed -i "s|audit_store=.*|audit_store=solr|g" install.properties
sudo sed -i "s|audit_solr_urls=.*|audit_solr_urls=http://localhost:8983/solr/ranger_audits|g" install.properties
sudo sed -i "s|policymgr_external_url=.*|policymgr_external_url=http://$hostname:6080|g" install.properties
#Update LDAP properties
sudo sed -i "s|authentication_method=.*|authentication_method=LDAP|g" install.properties
sudo sed -i "s|xa_ldap_url=.*|xa_ldap_url=$ldap_server_url|g" install.properties
sudo sed -i "s|xa_ldap_userDNpattern=.*|xa_ldap_userDNpattern=uid={0},cn=users,$ldap_base_dn|g" install.properties
sudo sed -i "s|xa_ldap_groupSearchBase=.*|xa_ldap_groupSearchBase=$ldap_base_dn|g" install.properties
sudo sed -i "s|xa_ldap_groupSearchFilter=.*|xa_ldap_groupSearchFilter=objectclass=group|g" install.properties
sudo sed -i "s|xa_ldap_groupRoleAttribute=.*|xa_ldap_groupRoleAttribute=cn|g" install.properties
sudo sed -i "s|xa_ldap_base_dn=.*|xa_ldap_base_dn=$ldap_base_dn|g" install.properties
sudo sed -i "s|xa_ldap_bind_dn=.*|xa_ldap_bind_dn=$ldap_bind_user_dn|g" install.properties
sudo sed -i "s|xa_ldap_bind_password=.*|xa_ldap_bind_password=$ldap_bind_password|g" install.properties
sudo sed -i "s|xa_ldap_referral=.*|xa_ldap_referral=ignore|g" install.properties
sudo sed -i "s|xa_ldap_userSearchFilter=.*|xa_ldap_userSearchFilter=(sAMAccountName={0})|g" install.properties
chmod +x setup.sh
./setup.sh
#Update ranger usersync install.properties
cd $installpath
tar -xvf $ranger_user_sync.tar.gz
cd $ranger_user_sync
sudo sed -i "s|POLICY_MGR_URL =.*|POLICY_MGR_URL=http://$hostname:6080|g" install.properties
sudo sed -i "s|SYNC_SOURCE =.*|SYNC_SOURCE=ldap|g" install.properties
sudo sed -i "s|SYNC_LDAP_URL =.*|SYNC_LDAP_URL=$ldap_server_url|g" install.properties
sudo sed -i "s|SYNC_LDAP_BIND_DN =.*|SYNC_LDAP_BIND_DN=$ldap_bind_user_dn|g" install.properties
sudo sed -i "s|SYNC_LDAP_BIND_PASSWORD =.*|SYNC_LDAP_BIND_PASSWORD=$ldap_bind_password|g" install.properties
sudo sed -i "s|SYNC_LDAP_SEARCH_BASE =.*|SYNC_LDAP_SEARCH_BASE=$ldap_base_dn|g" install.properties
sudo sed -i "s|SYNC_LDAP_USER_SEARCH_BASE =.*|SYNC_LDAP_USER_SEARCH_BASE=cn=users,$ldap_base_dn|g" install.properties
sudo sed -i "s|SYNC_LDAP_USER_SEARCH_FILTER =.*|SYNC_LDAP_USER_SEARCH_FILTER=objectclass=user|g" install.properties
sudo sed -i "s|SYNC_LDAP_USER_NAME_ATTRIBUTE =.*|SYNC_LDAP_USER_NAME_ATTRIBUTE=sAMAccountName|g" install.properties
sudo sed -i "s|SYNC_INTERVAL =.*|SYNC_INTERVAL=2|g" install.properties
chmod +x setup.sh
./setup.sh
#Download the install solr for ranger
cd $installpath
tar -xvf solr_for_audit_setup.tar.gz
cd solr_for_audit_setup
sudo sed -i "s|SOLR_HOST_URL=.*|SOLR_HOST_URL=http://$hostname:8983|g" install.properties
sudo sed -i "s|SOLR_RANGER_PORT=.*|SOLR_RANGER_PORT=8983|g" install.properties
chmod +x setup.sh
./setup.sh
#Start Ranger Admin
sudo /usr/bin/ranger-admin stop || true
sudo /usr/bin/ranger-admin start
i=0;
while ! timeout 1 bash -c "echo > /dev/tcp/$hostname/6080"; do
        sleep 10;
        i=$((i + 1))
        if (( i > 6 )); then
                break;
        fi
done
#Start Ranger Usersync
/usr/bin/ranger-usersync stop || true
/usr/bin/ranger-usersync start
# The default usersync runs every 1 hour (cannot be changed). This is way to force usersync
#sudo echo /usr/bin/ranger-usersync restart | at now + 5 minutes
#sudo echo /usr/bin/ranger-usersync restart | at now + 7 minutes
#sudo echo /usr/bin/ranger-usersync restart | at now + 10 minutes
#Start SOLR
#/opt/solr/bin/solr stop -p 8983 || true
#/opt/solr/bin/solr start
sudo /opt/solr/ranger_audit_server/scripts/stop_solr.sh || true
sudo /opt/solr/ranger_audit_server/scripts/start_solr.sh
#Add the new awss3 configuration
cd $installpath
wget $s3bucket_http_url/inputdata/ranger-servicedef-s3.json
sudo cp /usr/lib/ranger/ranger-0.7.1-admin/ews/webapp/WEB-INF/classes/ranger-plugins/hdfs/ranger-hdfs-plugin-0.7.1.jar /usr/lib/ranger/ranger-0.7.1-admin/ews/webapp/WEB-INF/classes/ranger-plugins/awss3/
#curl -u admin:admin -X DELETE http://localhost:6080/service/public/v2/api/servicedef/name/awss3
curl -u admin:admin -X POST -H "Accept: application/json" -H "Content-Type: application/json" http://localhost:6080/service/public/v2/api/servicedef -d @ranger-servicedef-s3.json
