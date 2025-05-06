#!/bin/bash

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  restartPolicy: Never
  containers:
    - name: gpu-container
      image: quay.io/centos/centos
      command: ["/bin/bash", "-c", "sleep 3600"]
      resources:
        requests:
          nvidia.com/gpu: 2
        limits:
          nvidia.com/gpu: 2 # requesting 2 GPU
  runtimeClassName: nvidia
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
