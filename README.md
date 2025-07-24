# 可信賴雲kolla-ansible 安裝腳本

**請先透過install.sh安裝完kolla-ansible及佈署openstack後再透過keystone_setup設定ldap**

**安裝流程:**
**安裝需要的套件->設定docker(將user加入group)->設定python venv跟安裝package->設定kolla config -> 設定nfs-server -> 安裝kolla openstack** 
```bash=
git clone https://git.narl.org.tw/gitlab-ee/LU-CHIN-CHIEN/kolla-ansible.git
cd kolla-ansible
./install.sh
#請確認可透過openstack-cli連線
openstack user list
#確認可以後再RUN keystone_setup.sh
./keystone_setup.sh
```
