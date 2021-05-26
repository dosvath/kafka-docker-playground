docker cp ./connect-krb5.conf connect:/etc/krb5.conf
docker cp ./connect-ssh-config connect:/etc/ssh/ssh_config
docker cp ./sshuser.keytab connect:/home/appuser/sshuser.keytab
docker exec -u 0 connect chown appuser:appuser sshuser.keytab

curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
        "topics": "test_sftp_sink",
               "tasks.max": "1",
               "connector.class": "io.confluent.connect.sftp.SftpSinkConnector",
               "partitioner.class": "io.confluent.connect.storage.partitioner.DefaultPartitioner",
               "schema.generator.class": "io.confluent.connect.storage.hive.schema.DefaultSchemaGenerator",
               "flush.size": "3",
               "schema.compatibility": "NONE",
               "format.class": "io.confluent.connect.sftp.sink.format.avro.AvroFormat",
               "storage.class": "io.confluent.connect.sftp.sink.storage.SftpSinkStorage",
               "sftp.host": "<mapped ip>",
               "sftp.port": "2222",
               "kerberos.keytab.path": "/home/appuser/sshuser.keytab",
               "kerberos.user.principal": "sshuser@EXAMPLE.COM",
               "sftp.username": "sshuser",
               "sftp.working.dir": "/upload",
               "confluent.license": "",
               "confluent.topic.bootstrap.servers": "broker:9092",
               "confluent.topic.replication.factor": "1"
          }' \
     http://localhost:8083/connectors/sftp-sink/config | jq .
