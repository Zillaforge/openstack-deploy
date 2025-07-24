DOMAIN=trustedcloud
PROJECT=trustedcloud 
#OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
#OS_CLOUD=kolla-admin
container_name="keystone"
source $HOME/venv/bin/activate
source /etc/kolla/admin-openrc.sh
while true; do
    echo "Checking OpenStack availability..."

    # Capture output and status
    output=$(openstack host list 2>&1)
    status=$?
    # Check if the command succeeded and contains a valid table header
    if [[ $status -eq 0 && "$output" == *"| Host Name"* && "$output" == *"| Service"* ]]; then
        echo "OpenStack is accessible."
        echo "===================="
        echo "OpenStack Host List:"
        echo "===================="
        echo "$output"
        echo "===================="
        break
    else
        echo "OpenStack not accessible yet. Retrying in 5 seconds..."
        sleep 5
    fi
done

# Execute Keystone setup script
echo "Running keystone_setup.sh..."
