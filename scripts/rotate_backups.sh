#!/usr/bin/bash

backups_dir=/opt/db_backups
partition=/dev/mapper/centos-root
os_host=x.x.x.x

cd $backups_dir
find . ! -name . -type d -mtime 7 -exec rm -rf {} +

echo $(date +"%Y-%m-%d %H:%M:%S"),disk_usage,$(df --output=pcent $partition | tr -dc '0-9')% >> backup_postgres_log.csv

timestamp=$(date +"%Y-%m-%dT%H:%M:%S.000Z" -d "-3 hours")
disk_usage=$(df --output=pcent $partition | tr -dc '0-9')
cat << EOF > $backups_dir/message_opensearch.json
{"@timestamp": "$timestamp", "disk_usage": "$disk_usage"}
EOF

curl -X POST -u admin:admin --insecure "https://$os_host:9200/backup_postgres/_doc" -H 'Content-Type: application/json'  -d @message_opensearch.json
