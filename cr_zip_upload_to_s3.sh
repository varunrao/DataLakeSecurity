#!/usr/bin/env bash
cd python-code;
zip -r ../LaunchCluster.zip *;
#aws s3 cp ../LaunchCluster.zip s3://skkodali-proserve/knox-blog/

#aws s3 cp ../scripts/knox-kerberos-setup-on-emr.sh s3://skkodali-public/blogs/scripts/knox/
#aws s3 cp ../scripts/knox-install.sh s3://skkodali-public/blogs/scripts/knox/

#aws s3 cp scripts/ranger-kerberos-setup-on-emr.sh s3://skkodali-public/blogs/scripts/ranger/
#aws s3 cp scripts/ranger-install.sh s3://skkodali-public/blogs/scripts/ranger/


aws s3 cp ../LaunchCluster.zip s3://skkodali-proserv-us-west-2/knox-blog/
aws s3 cp ../scripts/knox-kerberos-setup-on-emr.sh s3://skkodali-proserv-us-west-2/knox-blog/scripts/knox/
aws s3 cp ../scripts/knox-install.sh s3://skkodali-proserv-us-west-2/knox-blog/scripts/knox/

aws s3 cp ../scripts/ranger-kerberos-setup-on-emr.sh s3://skkodali-proserv-us-west-2/knox-blog/scripts/ranger/
aws s3 cp ../scripts/ranger-install.sh s3://skkodali-proserv-us-west-2/knox-blog/scripts/ranger/