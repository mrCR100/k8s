# k8s管理Nvidia GPU

## 查看Nvidia驱动

查看服务器上的Nvidia GPU PCI设备信息

        root@test-H3C-UniServer-R5300-G6:/home/test/Downloads# lspci|grep -i nvidia
        08:00.0 3D controller: NVIDIA Corporation Device 26ba (rev a1)
        09:00.0 3D controller: NVIDIA Corporation Device 26ba (rev a1)
        0e:00.0 3D controller: NVIDIA Corporation Device 26ba (rev a1)
        11:00.0 3D controller: NVIDIA Corporation Device 26ba (rev a1)
        32:00.0 3D controller: NVIDIA Corporation Device 26ba (rev a1)
        38:00.0 3D controller: NVIDIA Corporation Device 26ba (rev a1)
        3b:00.0 3D controller: NVIDIA Corporation Device 26ba (rev a1)
        3c:00.0 3D controller: NVIDIA Corporation Device 26ba (rev a1)

        root@test-H3C-UniServer-R5300-G6:/home/test/Downloads# nvidia-smi
        Wed Feb  5 16:14:01 2025
        +-----------------------------------------------------------------------------------------+
        | NVIDIA-SMI 550.120                Driver Version: 550.120        CUDA Version: 12.4     |
        |-----------------------------------------+------------------------+----------------------+
        | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
        | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
        |                                         |                        |               MIG M. |
        |=========================================+========================+======================|
        |   0  NVIDIA L20                     Off |   00000000:08:00.0 Off |                    0 |
        | N/A   32C    P8             24W /  350W |      10MiB /  46068MiB |      0%      Default |
        |                                         |                        |                  N/A |
        +-----------------------------------------+------------------------+----------------------+
        |   1  NVIDIA L20                     Off |   00000000:09:00.0 Off |                    0 |
        | N/A   32C    P8             25W /  350W |      10MiB /  46068MiB |      0%      Default |
        |                                         |                        |                  N/A |
        +-----------------------------------------+------------------------+----------------------+
        |   2  NVIDIA L20                     Off |   00000000:0E:00.0 Off |                    0 |
        | N/A   32C    P8             24W /  350W |      10MiB /  46068MiB |      0%      Default |
        |                                         |                        |                  N/A |
        +-----------------------------------------+------------------------+----------------------+
        |   3  NVIDIA L20                     Off |   00000000:11:00.0 Off |                    0 |
        | N/A   31C    P8             26W /  350W |      10MiB /  46068MiB |      0%      Default |
        |                                         |                        |                  N/A |
        +-----------------------------------------+------------------------+----------------------+
        |   4  NVIDIA L20                     Off |   00000000:32:00.0 Off |                    0 |
        | N/A   32C    P8             25W /  350W |      10MiB /  46068MiB |      0%      Default |
        |                                         |                        |                  N/A |
        +-----------------------------------------+------------------------+----------------------+
        |   5  NVIDIA L20                     Off |   00000000:38:00.0 Off |                    0 |
        | N/A   33C    P8             24W /  350W |      10MiB /  46068MiB |      0%      Default |
        |                                         |                        |                  N/A |
        +-----------------------------------------+------------------------+----------------------+
        |   6  NVIDIA L20                     Off |   00000000:3B:00.0 Off |                    0 |
        | N/A   33C    P8             24W /  350W |      10MiB /  46068MiB |      0%      Default |
        |                                         |                        |                  N/A |
        +-----------------------------------------+------------------------+----------------------+
        |   7  NVIDIA L20                     Off |   00000000:3C:00.0 Off |                    0 |
        | N/A   33C    P8             25W /  350W |      10MiB /  46068MiB |      0%      Default |
        |                                         |                        |                  N/A |
        +-----------------------------------------+------------------------+----------------------+

        +-----------------------------------------------------------------------------------------+
        | Processes:                                                                              |
        |  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
        |        ID   ID                                                               Usage      |
        |=========================================================================================|
        |    0   N/A  N/A   1164332      G   /usr/lib/xorg/Xorg                              4MiB |
        |    1   N/A  N/A   1164332      G   /usr/lib/xorg/Xorg                              4MiB |
        |    2   N/A  N/A   1164332      G   /usr/lib/xorg/Xorg                              4MiB |
        |    3   N/A  N/A   1164332      G   /usr/lib/xorg/Xorg                              4MiB |
        |    4   N/A  N/A   1164332      G   /usr/lib/xorg/Xorg                              4MiB |
        |    5   N/A  N/A   1164332      G   /usr/lib/xorg/Xorg                              4MiB |
        |    6   N/A  N/A   1164332      G   /usr/lib/xorg/Xorg                              4MiB |
        |    7   N/A  N/A   1164332      G   /usr/lib/xorg/Xorg                              4MiB |
        +-----------------------------------------------------------------------------------------+

nvidia驱动可以通过<https://www.nvidia.cn/drivers/lookup/>查找和安装

## 安装Nvidia Container Toolkit

Nvidia Container Toolkit主要的作用是使得容器能够使用Nvidia GPU

        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

        sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list

        sudo apt-get update
        sudo apt-get install -y nvidia-container-toolkit

### 配置containerd, 使containerd支持nvidia运行时

        sudo nvidia-ctk runtime configure --runtime=containerd
        sudo systemctl restart containerd

查看nvidia运行时是否配置成功

        crictl info
        ...
        "runtimes": {
                "nvidia": {
                "ContainerAnnotations": [],
                "PodAnnotations": [],
                "baseRuntimeSpec": "",
                "cniConfDir": "",
                "cniMaxConfNum": 0,
                "options": {
                    "BinaryName": "/usr/bin/nvidia-container-runtime",
                    "CriuImagePath": "",
        ...

## 安装Nvidia Device Plugin

    wget https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.0/deployments/static/nvidia-device-plugin.yml
    
### 增加nvidia运行时

vi runtimeClass.yaml

    apiVersion: node.k8s.io/v1
    kind: RuntimeClass
    metadata:
    name: nvidia
    handler: nvidia

### 配置Nvidia Device Plugin使用nvidia运行时  

vi nvidia-device-plugin.yml

        ...
        spec:
          ...
          runtimeClassName: nvidia

### 创建Nvidia Device Plugin

    kubectl create -f runtimeClass.yaml
    kubectl create -f nvidia-device-plugin.yml

### 查看Nvidia Device Plugin是否创建成功

    root@test-H3C-UniServer-R5300-G6:/home/test/k8s_install/nvidia# kubectl get po -A|grep -i nvidia-device-plugin
    kube-system        nvidia-device-plugin-daemonset-l854f                  1/1     Running   0                4h43m

因为目前集群只有一个节点, 所以Nvidia Device Plugin只有一个Pod。

查看节点信息。发现节点上可被分配的资源"nvidia.com/gpu"有8个。这说明Nvidia Device Plugin已经上报了节点上的Nvidia GPU资源。

     kubectl get node test-h3c-uniserver-r5300-g6 -o jsonpath='{.status.allocatable}'

     {
    "cpu": "128",
    "ephemeral-storage": "423798518697",
    "hugepages-1Gi": "0",
    "hugepages-2Mi": "0",
    "memory": "527907264Ki",
    "nvidia.com/gpu": "8",
    "pods": "110"
    }

## 参考

<https://github.com/NVIDIA/k8s-device-plugin>
<https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>
<https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/sample-workload.html>