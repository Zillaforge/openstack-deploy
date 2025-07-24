export HOME=$(eval echo ~$SUDO_USER)
export ADDR=$(ip -o -4 route show to default | awk '{print $9}')
export OS_USERNAME=test@trusted-cloud.nchc.org.tw
export OS_PROJECT_NAME=trustedcloud
export OS_USER_DOMAIN_NAME=trustedcloud
export OS_PROJECT_DOMAIN_NAME=trustedcloud
export OS_AUTH_URL=http://$ADDR:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_PASSWORD='password123'
source $HOME/venv/bin/activate
