#!/usr/bin/env bash
cd python-code;
zip -r ../LaunchCluster.zip *;
aws s3 cp ../LaunchCluster.zip s3://skkodali-proserve/knox-blog/
aws s3 cp ../scripts/knox-kerberos-setup-on-emr.sh s3://skkodali-proserve/knox-blog/
aws s3 cp ../scripts/knox-install.sh s3://skkodali-proserve/knox-blog/