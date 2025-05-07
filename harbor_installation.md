# 部署harbor

## 安装helm工具

如果k8s主节点上没有安装helm

    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

## 安装harbor

### 添加 harbor helm 仓库

    helm repo add harbor https://helm.goharbor.io
    helm repo update

### 创建命名空间

    kubectl create namespace harbor

### 创建harbor所使用的本地存储

    root@test-H3C-UniServer-R5300-G6:/home/test/k8s_install/harbor#
    kubectl get pv
    NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                      STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    local-pv-harbor   200Gi      RWO            Retain           Bound    default/local-pvc-harbor                  <unset>                          4s
    root@test-H3C-UniServer-R5300-G6:/home/test/k8s_install/harbor# kubectl get pvc
    NAME               STATUS   VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
    local-pvc-harbor   Bound    local-pv-harbor   200Gi      RWO     

### helm安装或者更新harbor chart包

    helm upgrade --install harbor harbor/harbor -n harbor -f values.yaml

### 卸载harbor chart包

    helm uninstall harbor -n harbor

### 升级harbor chart包

    helm upgrade harbor harbor/harbor -n harbor -f values.yaml

### harbor chart包中所用镜像

goharbor/harbor-core:v2.13.0
goharbor/nginx-photon:v2.13.0
goharbor/harbor-portal:v2.13.0
goharbor/harbor-registryctl:v2.13.0
goharbor/trivy-adapter-photon:v2.13.0
goharbor/redis-photon:v2.13.0
goharbor/harbor-jobservice:v2.13.0
goharbor/harbor-db:v2.13.0
goharbor/registry-photon:v2.13.0

    ctr -n k8s.io image import goharbor_harbor-core.tar
    ctr -n k8s.io image import goharbor_harbor-portal.tar
    ctr -n k8s.io image import goharbor_nginx-photon.tar
    ctr -n k8s.io image import goharbor_harbor-db.tar
    ctr -n k8s.io image import goharbor_harbor-registryctl.tar
    ctr -n k8s.io image import goharbor_trivy-adapter-photon.tar
    ctr -n k8s.io image import goharbor_redis-photon.tar
    ctr -n k8s.io image import goharbor_harbor-jobservice.tar
    ctr -n k8s.io image import goharbor_registry-photon.tar

## 使用harbor

### 推送镜像至harbor

    ctr -n k8s.io image import library_docker.tar
    kubectl apply -f cli.yaml
    kubectl exec -it harbor-cli -n harbor -- sh
    docker login http://100.84.115.22:30080 -u admin -p Harbor12345
    docker push 100.84.115.22:30080/library/hello-world:latest

## 已知问题

### 无法推送镜像到harbor

    (base) root@dell-Precision-7960-Tower:~/docker_images# docker login http://100.84.115.22:30080 -u admin -p Harbor12345
    WARNING! Using --password via the CLI is insecure. Use --password-stdin.
    Error response from daemon: Get "http://100.84.115.22:30080/v2/": Get "https://core.harbor.domain/service/token?account=admin&client_id=docker&offline_token=true&service=harbor-registry": dial tcp: lookup core.harbor.domain on 127.0.0.53:53: no such host

需要配置externalUrl变量。

## 遗留问题

### harbor命名空间的pod内无法解析harbor地址

    / # docker login -u admin -p Harbor12345 http://harbor-core.harbor.svc.cluster.local
    WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Error response from daemon: Get "http://harbor-core.harbor.svc.cluster.local/v2/": dial tcp: lookup harbor-core.harbor.svc.cluster.local: no such host

但是使用nslookup可以正常解析。

    / # docker login -u admin -p Harbor12345 http://harbor/
    WARNING! Using --password via the CLI is insecure. Use --password-stdin.
    Error response from daemon: Get "http://harbor/v2/": dial tcp: lookup harbor on 127.0.0.53:53: server misbehaving
