#!/usr/bin/bash

backups_dir=/opt/db_backups
postgres_host=x.x.x.x
os_host=x.x.x.x

cd $backups_dir
mkdir -p "backup_$(date +%Y-%m-%d)"
cd "$backups_dir/backup_$(date +%Y-%m-%d)"

{ # try

    pg_basebackup -P -Xstream -z -Ft -h $postgres_host -p 5432 -U repl -D . &&
    #save your output
    echo $(date +"%Y-%m-%d %H:%M:%S"),get_backup_status,Success >> ../backup_postgres_log.csv
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S.000Z" -d "-3 hours")
    cat << EOF > $backups_dir/message_opensearch.json
{"@timestamp": "$timestamp", "backup_status": "Success"}
EOF

} || { # catch
    echo $(date +"%Y-%m-%d %H:%M:%S"),get_backup_status,Failure >> ../backup_postgres_log.csv
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S.000Z" -d "-3 hours")
    cat << EOF > $backups_dir/message_opensearch.json
{"@timestamp": "$timestamp", "backup_status": "Failure"}
EOF
    # save log for exception
}
cd $backups_dir
curl -X POST -u admin:admin --insecure "https://$os_host:9200/backup_postgres/_doc" -H 'Content-Type: application/json' -d @message_opensearch.json
