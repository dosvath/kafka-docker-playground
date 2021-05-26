#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

docker cp ./connect-krb5.conf connect:/etc/krb5.conf
docker cp ./connect-ssh-config connect:/etc/ssh/ssh_config
docker cp ./sshuser.keytab connect:/home/appuser/sshuser.keytab
docker exec -u 0 connect chown appuser:appuser sshuser.keytab
#docker exec connect kinit sshuser -k -t sshuser.keytab

docker exec ssh-container_ssh-server_1 bash -c "
mkdir -p /home/sshuser/upload/input
mkdir -p /home/sshuser/upload/error
mkdir -p /home/sshuser/upload/finished

chown -R sshuser /home/sshuser/upload
"

echo $'id,first_name,last_name,email,gender,ip_address,last_login,account_balance,country,favorite_color\n1,Salmon,Baitman,sbaitman0@feedburner.com,Male,120.181.75.98,2015-03-01T06:01:15Z,17462.66,IT,#f09bc0\n2,Debby,Brea,dbrea1@icio.us,Female,153.239.187.49,2018-10-21T12:27:12Z,14693.49,CZ,#73893a' > csv-sftp-source.csv
docker cp csv-sftp-source.csv ssh-container_ssh-server_1:/home/sshuser/upload/input/
rm -f csv-sftp-source.csv

log "Creating CSV SFTP Source connector"
curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
        "topics": "test_sftp_sink",
               "tasks.max": "1",
               "connector.class": "io.confluent.connect.sftp.SftpCsvSourceConnector",
               "cleanup.policy":"NONE",
               "behavior.on.error":"IGNORE",
               "input.path": "/home/sshuser/upload/input",
               "error.path": "/home/sshuser/upload/error",
               "finished.path": "/home/sshuser/upload/finished",
               "input.file.pattern": "csv-sftp-source.csv",
               "sftp.username":"sshuser",
               "kerberos.keytab.path": "/home/appuser/sshuser.keytab",
               "kerberos.user.principal": "sshuser",
               "sftp.host":"<mapped.ip>",
               "sftp.port":"2222",
               "kafka.topic": "sftp-testing-topic",
               "csv.first.row.as.header": "true",
               "schema.generation.enabled": "true"
          }' \
     http://localhost:8083/connectors/sftp-source-csv/config | jq .

sleep 5

log "Verifying topic sftp-testing-topic"
timeout 60 docker exec connect kafka-avro-console-consumer -bootstrap-server broker:9092 --property schema.registry.url=http://schema-registry:8081 --topic sftp-testing-topic --from-beginning --max-messages 2
