#!/usr/bin/bash

backups_dir=/opt/db_backups
version=15
postgres_dir=/var/lib/pgsql/$version/data
os_host=x.x.x.x

is_running=$(systemctl is-active postgresql-$version.service)
echo $is_running
if [ $is_running = "active" ]; then
        echo  "Postgresql $version is running"
	systemctl stop "postgresql-$version.service"
else
        echo "Postgresql $version is not running"
fi

cd $postgres_dir
rm -rf ./*
tar -zxf $backups_dir/backup_$(date +%Y-%m-%d)/base.tar.gz -C $postgres_dir
touch recovery.signal
chown postgres:postgres recovery.signal

rm -rf $backups_dir/pg_wal/
mkdir $backups_dir/pg_wal/
tar -zxf $backups_dir/backup_$(date +%Y-%m-%d)/pg_wal.tar.gz -C $backups_dir/pg_wal/
chmod 755 $backups_dir/pg_wal 
chown -R postgres:postgres $backups_dir/pg_wal

echo "restore_command = 'cp $backups_dir/pg_wal/%f %p'" >> $postgres_dir/postgresql.conf
systemctl start "postgresql-$version.service"

cd $backups_dir
is_running=$(systemctl is-active postgresql-$version.service)
echo $is_running
if [ $is_running = "active" ]; then
	echo $(date +"%Y-%m-%d %H:%M:%S"),restore_status,Success >> backup_postgres_log.csv
        timestamp=$(date +"%Y-%m-%dT%H:%M:%S.000Z" -d "-3 hours")
        cat << EOF > $backups_dir/message_opensearch.json
{"@timestamp": "$timestamp", "restore_status": "Success"}
EOF
else
	echo $(date +"%Y-%m-%d %H:%M:%S"),restore_status,Failure >> backup_postgres_log.csv
        timestamp=$(date +"%Y-%m-%dT%H:%M:%S.000Z" -d "-3 hours")
        cat << EOF > $backups_dir/message_opensearch.json
{"@timestamp": "$timestamp", "restore_status": "Failure"}
EOF
fi

cd $backups_dir
curl -X POST -u admin:admin --insecure "https://$os_host:9200/backup_postgres/_doc" -H 'Content-Type: application/json'  -d @message_opensearch.json
