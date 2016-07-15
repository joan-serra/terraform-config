#!/bin/bash

set -o errexit

ip link set eth0 mtu 1500

export INSTANCE_ID="$(curl -s 'http://169.254.169.254/latest/meta-data/instance-id')"
export INSTANCE_IPV4="$(curl -s 'http://169.254.169.254/latest/meta-data/local-ipv4')"

cd /tmp

export INSTANCE_HOST_NAME="worker-linux-${queue}-$${INSTANCE_ID#i-}.${env}.travis-ci.${site}"

if [ -d /home/moustache ]; then
  cat >> /home/moustache/.ssh/authorized_keys <<EOF
${ssh_keys}
EOF
fi

cat > docker_rsa <<EOF
${docker_rsa}
EOF

cat > travis-worker.yml <<EOF
${worker_yml}
EOF

cat > papertrail.conf <<EOF
\$DefaultNetstreamDriverCAFile /etc/papertrail.crt
\$DefaultNetstreamDriver gtls
\$ActionSendStreamDriverMode 1
\$ActionSendStreamDriverAuthMode x509/name

*.* @@${papertrail_site}
EOF

cat > watch-files.conf <<EOF
\$ModLoad imfile
\$InputFileName /etc/sv/travis-worker/log/main/current
\$InputFileTag travis-worker
\$InputFileStateFile state_file_worker_log
\$InputFileFacility local7
\$InputRunFileMonitor
\$InputFilePollInterval 10
EOF

# There are no safeguards against generating a hostname longer than 64 bytes, soo ... `|| true`!
echo "$INSTANCE_HOST_NAME" > /etc/hostname || true
hostname -F /etc/hostname || true

echo "$INSTANCE_IPV4 $INSTANCE_HOST_NAME $${INSTANCE_HOST%.*}" >> /etc/hosts

sed -i -e "s/^Hostname.*$/Hostname \"$INSTANCE_HOST_NAME\"/" /etc/collectd/collectd.conf
service collectd restart

travis-docker-volume-setup

DOCKER_DATA_SPACE_TOTAL="$(lvs -o lv_size --noheadings /dev/direct-lvm/data --units M | xargs echo | sed 's/M//')"
EXPECTED_DOCKER_IMAGE_USAGE_MB="30000"
DOCKER_STORAGE_OPT_DM_BASESIZE="$(echo "($DOCKER_DATA_SPACE_TOTAL - $EXPECTED_DOCKER_IMAGE_USAGE_MB) / ${docker_count}" | bc)MB"
echo "DOCKER_STORAGE_OPT_DM_BASESIZE=$DOCKER_STORAGE_OPT_DM_BASESIZE" > /etc/default/docker.cloud-init

mkdir /home/deploy/.ssh
chown travis:travis /home/deploy/.ssh
chmod 0700 /home/deploy/.ssh
mv docker_rsa /home/deploy/.ssh/docker_rsa
chown travis:travis /home/deploy/.ssh/docker_rsa
chmod 0600 /home/deploy/.ssh/docker_rsa
mv travis-worker.yml /home/deploy/travis-worker/config/worker.yml
chown travis:travis /home/deploy/travis-worker/config/worker.yml
chmod 0600 /home/deploy/travis-worker/config/worker.yml

mv watch-files.conf /etc/rsyslog.d/60-watch-files.conf
mv papertrail.conf /etc/rsyslog.d/65-papertrail.conf
service rsyslog restart

rm -rf /var/lib/cloud/instances/*

# Remove access to the EC2 metadata API
if ! iptables -t nat -C PREROUTING -p tcp -d 169.254.169.254 --dport 80 -j DNAT --to-destination 192.0.2.1; then
  iptables -t nat -I PREROUTING -p tcp -d 169.254.169.254 --dport 80 -j DNAT --to-destination 192.0.2.1
fi

# cronjob to shut down borked docker (linux kernel bug)
echo '* * * * * dmesg | grep -q unregister_netdevice && /sbin/shutdown -P now "unregister_netdevice detected, shutting down instance"' | crontab -