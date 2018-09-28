#!/bin/bash

# to create a different machine (e.g. for testing), change these two lines
export HOST=tharsis002
export KEY=~/.ssh/root_tharsis002_digital_ocean

# generates a new root key for the machine
if [ -f $KEY ]; then
  mv -f $KEY $KEY.backup
fi
ssh-keygen -q -N '' -f $KEY
export KEYID=$(doctl compute ssh-key import $HOST \
  --public-key-file $KEY.pub \
  --format ID \
  --no-header)

# create the machine
echo "Provisioning machine.  This may take several minutes..."
export IPV4=$(doctl compute droplet create $HOST \
  --size s-1vcpu-1gb \
  --image ubuntu-18-04-x64 \
  --region sgp1 \
  --ssh-keys $KEYID \
  --user-data-file sundog-userdata.sh \
  --format PublicIPv4 \
  --no-header \
  --wait)
doctl compute ssh-key delete $KEYID --force
echo $IPV4 > ~/Documents/Projects/Sundog/ip

# add data to the new server
echo -n "Machine created at $IPV4.  Waiting for response...";
until $(curl --output /dev/null --silent --head --fail http://$IPV4); do
  printf '.'
  sleep 5
done

# on host: ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub
# security risk.  todo: monkeysphere
export GIT_SSH_COMMAND="ssh -i $KEY -q -o StrictHostKeyChecking=no"
cd ~/Documents/Projects/Pavonis
git remote set-url origin root@$IPV4:/srv/git/tharsis.git
git push origin master
ssh -i $KEY root@$IPV4 "rm /srv/www/*; cd /srv/www; git pull"

cd ~/Documents/Projects/Arcadia
git remote set-url origin root@$IPV4:/srv/git/arcadia.git
git push origin master
ssh -i $KEY root@$IPV4 'bash -s' < ~/Documents/Projects/Sundog/sundog-arcadia-data.sh
