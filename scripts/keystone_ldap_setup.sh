DOMAIN=trustedcloud
PROJECT=trustedcloud 
#OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
#OS_CLOUD=kolla-admin
container_name="keystone"
source $HOME/venv/bin/activate
source /etc/kolla/admin-openrc.sh

echo "create domain $DOMAIN and project $PROJECT"
openstack domain create $DOMAIN
openstack project create $PROJECT --domain $DOMAIN

echo "restart keystone container"
sudo docker exec -it $container_name service apache2 restart


# Wait for container to report healthy
echo "Waiting for $container_name to become healthy..."
while [ "$(sudo docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null)" != "healthy" ]; do
  sleep 2
  status=$(sudo docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null)
  echo "Current status: $status"
  if [ "$status" == "unhealthy" ]; then
    echo "$container_name is unhealthy. Exiting."
  fi
done

echo "$container_name is healthy! Proceeding..."
# Your next command here
echo "List all user"
openstack user list --domain trustedcloud  -c Name
USERS=($(openstack user list --domain trustedcloud -c Name -f value ))
if [ ${#USERS[@]} -eq 0 ]; then
  echo "No users found in domain $DOMAIN. Exiting."
  exit 1
fi
echo "applying admin role to ladp user"
for user in "${USERS[@]}"; do
  echo "Assigning 'admin' role to user: $user"
  openstack role add   --user $user   --user-domain $DOMAIN   --project $PROJECT   --project-domain $DOMAIN   admin
done
