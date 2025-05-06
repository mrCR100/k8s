# k8s集群新增节点

## 安装k8s安装工具和docker软件包

### 配置k8s仓库

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

### 安装k8s的安装工具和独立组件（2025.02最新版本1.32.1-1.1）

    sudo apt-get update
    sudo apt-get install -y kubelet=1.32.1-1.1 kubeadm=1.32.1-1.1 kubectl=1.32.1-1.1
    sudo apt-mark hold kubelet kubeadm kubectl

### 启动kubelet服务

启动后kubelet会反复重启，因为还缺少kubeadm对于kubelet的配置。

    sudo systemctl enable --now kubelet

### 配置docker镜像仓库

    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

    注意：
    需要手动下载gpg文件。

    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

### 安装docker相关软件包

    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

#### 配置containerd

切换root用户

    containerd config default > /etc/containerd/config.toml
修改配置文件，编辑如下内容：

    vi /etc/containerd/config.toml

    [plugins."io.containerd.grpc.v1.cri"]
        ...
          sandbox_image="registry.aliyuncs.com/google_containers/pause:3.10"
        ...
          systemd_group = false
        ...
        [plugins."io.containerd.grpc.v1.cri".registry]
          [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
            [plugins."io.containerd.grpc.v1.cri".registry.mirrors."*"]
              endpoint = ["registry.aliyuncs.com/google_containers"]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      ...
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true

#### 重启containerd

    sudo systemctl restart containerd

#### 下载pause镜像

    docker pull registry.aliyuncs.com/google_containers/pause:3.10
    docker save -o pause3.10.tar registry.aliyuncs.com/google_containers/pause:3.10
    ctr -n k8s.io image import pause3.10.tar

## 关闭swap分区

kubelet的正常运行需要关闭swap分区。

### 查看swap分区

    swapon -show

### 临时关闭swap分区

    sudo swapoff -a

### 永久关闭swap分区

    vi /etc/fstab

注释掉配置swap分区的那一行。

## 新节点加入集群

### 主节点确认集群token信息

    kubeadm token list

如果没有任何输出，说明集群之前的token过期了。

### 主节点生成新的token

    kubeadm token create

### 主节点获取CA公钥的哈希值

    openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^ .* //'

### 新节点执行加入命令

kubeadm join 100.84.115.22:6443 --token nc088v.it5cbi6pnuea4496  \
            --discovery-token-ca-cert-hash sha256:8cbb87abe73560e439c502998f84cea8a3597173d8a0d08f030e2511755007ef

### 手动下载calico镜像

    crictl pull quay.io/calico/typha:v3.29.1
    crictl pull quay.io/calico/cni:v3.29.1
    crictl pull quay.io/calico/node-driver-registrar:v3.29.1
    crictl pull quay.io/calico/csi:v3.29.1
    crictl pull quay.io/calico/pod2daemon-flexvol:v3.29.1
    crictl pull quay.io/calico/node:v3.29.1
    crictl pull quay.io/calico/kube-controllers:v3.29.1
    crictl pull quay.io/calico/apiserver:v3.29.1

    ctr -n k8s.io images tag quay.io/calico/typha:v3.29.1 docker.io/calico/typha:v3.29.1
    ctr -n k8s.io images tag quay.io/calico/cni:v3.29.1 docker.io/calico/cni:v3.29.1
    ctr -n k8s.io images tag quay.io/calico/node-driver-registrar:v3.29.1 docker.io/calico/node-driver-registrar:v3.29.1
    ctr -n k8s.io images tag quay.io/calico/csi:v3.29.1 docker.io/calico/csi:v3.29.1
    ctr -n k8s.io images tag quay.io/calico/pod2daemon-flexvol:v3.29.1 docker.io/calico/pod2daemon-flexvol:v3.29.1
    ctr -n k8s.io images tag quay.io/calico/node:v3.29.1 docker.io/calico/node:v3.29.1
    ctr -n k8s.io images tag quay.io/calico/kube-controllers:v3.29.1 docker.io/calico/kube-controllers:v3.29.1
    ctr -n k8s.io images tag quay.io/calico/node-driver-registrar:v3.29.1 docker.io/calico/node-driver-registrar:v3.29.1
    ctr -n k8s.io images tag quay.io/calico/apiserver:v3.29.1 docker.io/calico/apiserver:v3.29.1
