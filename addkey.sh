#!/bin/bash
rm "/tmp/key.key" -f
rm "/tmp/key.key.pub" -f

ssh-keygen -t ecdsa -b 521 -f "/tmp/key.key" -P "" -q

cat "/tmp/key.key"
rm "/tmp/key.key" -f

PublicKey=`sudo cat /tmp/key.key.pub`
rm "/tmp/key.key.pub" -f

ExpirationTime=`date -d "1 minutes" +"%s"`
echo -e "#${ExpirationTime}\n${PublicKey}" >> "/home/templates/.ssh/authorized_keys"