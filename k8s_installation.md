# k8s安装

关于Kubernetes的安装，在Kubernetes官网上有详细的安装教程。通过部署工具安装相对简单。但是，因为国内网络环境的原因，需要做些修改，这些修改的内容主要是修改容器镜像的仓库地址（默认的容器镜像仓库地址网络不通）。另外，安装Kubernetes需要修改的配置项较多，很容易遗漏导致安装失败或者运行后异常，最终花费大量时间排查问题。所以，我将实验室服务器安装Kubernetes的要点以及注意事项记录下来，方便以后不时之需。

## 环境信息

服务器：H3C-UniServer-R5300-G6
操作系统：Ubuntu 22.04.5 LTS

## 安装过程

### 准备

    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg

### 配置k8s仓库

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

### 安装k8s的安装工具和独立组件（2025.02最新版本1.32.1-1.1）

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

### 启动kubelet服务

启动后kubelet会反复重启，因为还缺少kubeadm对于kubelet的配置。

    sudo systemctl enable --now kubelet

### 配置docker镜像仓库

    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

### 安装docker相关软件包

    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

注意：
k8s的CRI默认使用containerd作为容器运行时，如果使用docker作为容器运行时，还需要安装cri-docker软件包使docker兼容k8s CRI。但是cri-docker目前只支持容器运行时为docker，不支持nvidia等其他运行时。如果想使用nvidia GPU资源的话，无法使用docker作为k8s的容器运行时。

#### 配置containerd

切换root用户

    containerd config default > /etc/containerd/config.toml
修改配置文件，添加如下内容：

    vi /etc/containerd/config.toml

    [plugins."io.containerd.grpc.v1.cri"]
          sandbox_image="registry.aliyuncs.com/google_containers/pause:3.10"
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

### 关闭swap分区

kubelet的正常运行需要关闭swap分区。

#### 查看swap分区

    swapon –show

#### 临时关闭swap分区

    sudo swapoff -a

#### 永久关闭swap分区

    vi /etc/fstab
注释掉配置swap分区的那一行

### kubeadm创建集群

    kubeadm init --image-repository registry.aliyuncs.com/google_containers --apiserver-advertise-address=100.84.115.22 --kubernetes-version v1.32.1 --service-cidr=13.96.0.0/12 --pod-network-cidr=13.244.0.0/16 --cri-socket=unix:///run/containerd/containerd.sock

注意：
kubeadm init是创建集群的核心命令，需要根据实际情况进行配置。例如：
--apiserver-advertise-address配置为服务器的IP地址；
--image-repository配置为阿里云的镜像仓库地址；

#### 查看集群状态

成功后，会输出kubeadm join的命令，将该命令保存下来，后续需要使用，例如：
    Your Kubernetes control-plane has initialized successfully!

    To start using your cluster, you need to run the following as a regular user:

      mkdir -p $HOME/.kube
      sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
      sudo chown $(id -u):$(id -g) $HOME/.kube/config

    Alternatively, if you are the root user, you can run:

      export KUBECONFIG=/etc/kubernetes/admin.conf

    You should now deploy a pod network to the cluster.
    Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
      https://kubernetes.io/docs/concepts/cluster-administration/addons/

    Then you can join any number of worker nodes by running the following on each as root:

    kubeadm join 100.84.115.22:6443 --token 5rz64k.22e2ke8kl7kei2rl \
            --discovery-token-ca-cert-hash sha256:f2040f184a6414b82958f9a19f32d6e9b00acb77e41a18014f7a33fa15b3fef0

如果出现错误，需要参考错误信息进行排查。也可以参考官方文档：
<https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/>

执行kubectl get po -A, 查看k8s控制面组件是否正常运行。
正常情况下，除了coredns组件外，其他组件都应该处于Running状态。

### 安装网络插件

我选择安装calico，也可以选择flannel

#### 下载yaml文件

    wget https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml

    wget https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml

#### 修改Calico cidr字段配置为当前k8s集群的Pod cidr配置

    vi custom-resources.yaml
    cidr: 13.244.0.0/16

#### 安装calico

    kubectl create -f tigera-operator.yaml
    kubectl create -f custom-resources.yaml

#### 手动下载calico镜像

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

注意：
calico的安装部署使用k8s operator的方式，我浏览了一下，镜像的名称似乎在operator代码中定义的，规定为docker.io/calico/*，但是国内只能从quay.io仓库下载。所以我手动从quay.io仓库下载calico镜像，然后修改镜像名称为docker.io/calico/*

#### 去除污点

发现当前集群只有一个控制节点，且存在一个污点。

    kubectl get nodes -o wide -o yaml|grep -i -A 3 taint
    taints:
        - effect: NoSchedule
          key: node-role.kubernetes.io/control-plane

    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
注意：
kubectl taint命令有一个最后有一个"-"符号，表示去掉污点。

## 安装完成

当calico安装完成后，可以使用kubectl get po -A查看k8s集群的所有组件是否都处于Running状态。

    root@test-H3C-UniServer-R5300-G6:/home/test# kubectl get po -A
    NAMESPACE          NAME                                                  READY   STATUS    RESTARTS         AGE
    calico-apiserver   calico-apiserver-6484b7c86f-4bw57                     1/1     Running   0                4h4m
    calico-apiserver   calico-apiserver-6484b7c86f-wbndf                     1/1     Running   0                4h4m
    calico-system      calico-kube-controllers-7d87567b66-z4cpq              1/1     Running   0                4h4m
    calico-system      calico-node-qpvgt                                     1/1     Running   0                4h4m
    calico-system      calico-typha-6ffdb785c8-47ffh                         1/1     Running   0                4h4m
    calico-system      csi-node-driver-v4q8f                                 2/2     Running   0                4h4m
    kube-system        coredns-6766b7b6bb-k6tzq                              1/1     Running   0                4h18m
    kube-system        coredns-6766b7b6bb-trq8x                              1/1     Running   0                4h18m
    kube-system        etcd-test-h3c-uniserver-r5300-g6                      1/1     Running   31 (4h19m ago)   4h18m
    kube-system        kube-apiserver-test-h3c-uniserver-r5300-g6            1/1     Running   34 (4h19m ago)   4h19m
    kube-system        kube-controller-manager-test-h3c-uniserver-r5300-g6   1/1     Running   36 (4h20m ago)   4h18m
    kube-system        kube-proxy-lsk64                                      1/1     Running   0                4h18m
    kube-system        kube-scheduler-test-h3c-uniserver-r5300-g6            1/1     Running   39 (4h19m ago)   4h18m
    tigera-operator    tigera-operator-7d68577dc5-qqxvw                      1/1     Running   0                4h5m

## 参考

<https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/>
<https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd>
<https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart>
<https://github.com/kubernetes/kubeadm/issues/2686>
<https://github.com/kubernetes/kubernetes/issues/117293>
