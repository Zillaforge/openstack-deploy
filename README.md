# openstack 安裝腳本

```bash=
git clone https://github.com/Zillaforge/openstack-deploy.git
cd openstack-deploy
./install.sh
```

## 網路架構說明

此腳本設計用於在單一 VM 中部署一個 All-in-One 的 OpenStack 環境。在這種情境下，我們需要為 OpenStack 的虛擬機 (VMs) 提供一個可用的外部網路 (External Network)，以便它們可以透過 Floating IP 與外界溝通。

然而，託管 OpenStack 的主機 VM 通常只有一張主要的網路卡，這張網卡已經被用於主機自身的管理和連接。我們不能將這張網卡直接分配給 OpenStack 的 OVN (Open Virtual Network) 作為 `br-ex` (外部橋接器) 的物理介面，否則會導致主機失聯。

### 解決方案：虛擬網路介面

建立一個**虛擬的內部網路環境**來模擬外部網路。這個過程包含了幾個關鍵步驟：

1.  **建立 Linux Bridge (`dummy1`)**:
    *   我們首先建立一個名為 `dummy1` 的 Linux Bridge。這個 Bridge 的作用就像一台虛擬的網路交換機，它將作為我們模擬的「外部網路」。
    *   腳本會給 `dummy1` 分配一個靜態 IP (例如 `10.0.2.2/24`)，讓主機本身也能夠存取這個模擬的外部網路，方便後續的設定與除錯。

2.  **建立 Veth Pair (`veth-ovs` & `veth-br`)**:
    *   接著，我們建立一對虛擬的網路介面 (veth pair)，可以把它們想像成一條虛擬的網路線，一端是 `veth-ovs`，另一端是 `veth-br`。
    *   `veth-br` 會被「插入」到 `dummy1` 這個虛擬交換機上。
    *   `veth-ovs` 則會被交給 Kolla Ansible，並在 `globals.yml` 中設定為 `neutron_external_interface`。

### 運作原理

設定完成後，OpenStack (OVN) 在初始化時會建立一個名為 `br-ex` 的 OVS (Open vSwitch) Bridge，並將 `veth-ovs` 這個虛擬介面加入其中。

如此一來，整個網路的串接流程如下：

```ascii
+------------------+
|                  |
|   OpenStack VM   |
|                  |
+--------+---------+
         |
         v
+--------+---------+
|  OVN Virtual     |
|  Router          |
+--------+---------+
         |
         v
+--------+---------------------------------+
| OVN br-ex (Inside OpenStack)             |
|                                          |
|   +------------+                         |
|   |  veth-ovs  |                         |
|   +------------+                         |
+------------------------------------------+
               ||
               ||  <-- This is a veth pair
               ||
+--------+---------------------------------+
| dummy1 Bridge (On the Host VM)           |
|                                          |
|   +------------+                         |
|   |  veth-br   |                         |
|   +------------+                         |
+------------------------------------------+
```

透過這層虛擬的串接，OpenStack 的外部網路就成功地建立起來，並且與主機的管理網路完全隔離。這使得我們可以在 Neutron 中建立外部網路、分配 Floating IP，並讓 OpenStack 內的虛擬機認為它們正連接到一個真實的外部世界，而所有的網路流量實際上都只在這台主機 VM 內部流動。

