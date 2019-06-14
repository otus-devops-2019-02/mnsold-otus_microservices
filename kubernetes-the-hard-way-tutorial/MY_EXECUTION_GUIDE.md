

# Kubernetes The Hard Way

https://github.com/kelseyhightower/kubernetes-the-hard-way

Разбор сети https://habr.com/ru/company/flant/blog/420813/



#01 Prerequisites

```bash
gcloud version
Google Cloud SDK 239.0.0

gcloud config get-value compute/region
(unset)

gcloud config get-value compute/zone
(unset)
```

Set default compute region/compute zone

```
gcloud compute zones list

gcloud config set compute/region europe-west1
gcloud config set compute/zone europe-west1-c
```



# 02 Installing the Client Tools

## Install CFSSL

```bash
wget -q --show-progress --https-only --timestamping \
https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

```

## Install kubectl

```bash
wget https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

```



# 03 Provisioning Compute Resources

### Virtual Private Cloud Network

```bash
gcloud compute networks create kubernetes-the-hard-way --subnet-mode custom

gcloud compute networks subnets create kubernetes \
  --network kubernetes-the-hard-way \
  --range 10.240.0.0/24
```


### Firewall Rules

```bash
gcloud compute firewall-rules create kubernetes-the-hard-way-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 10.240.0.0/24,10.200.0.0/16

gcloud compute firewall-rules create kubernetes-the-hard-way-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 0.0.0.0/0
  
```

Список правил

```bash
gcloud compute firewall-rules list --filter="network:kubernetes-the-hard-way"
```

### Kubernetes Public IP Address

```bash
gcloud compute addresses create kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region)

# Verify the kubernetes-the-hard-way static IP address was created in your default compute region:
gcloud compute addresses list --filter="name=('kubernetes-the-hard-way')"
```

## Compute Instances

### Kubernetes Controllers

```bash
for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,controller
done

```

### Kubernetes Workers

```bash
for i in 0 1 2; do
  gcloud compute instances create worker-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --metadata pod-cidr=10.200.${i}.0/24 \
    --private-network-ip 10.240.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,worker
done
```

> При создании 5 и 6 ВМ получаю ошибку "ERROR: (gcloud.compute.instances.create) HTTPError 403: Quota 'IN_USE_ADDRESSES' exceeded. Limit: 4.0 in region europe-west1."
>
> Квоты:  IAM и администрирование > Квоты, Фильтр: Показатель=In-use IP addresses 
>
> https://console.cloud.google.com/iam-admin/quotas?authuser=1&project=docker-otus-201905&metric=In-use%20IP%20addresses

###Verification

```bash
gcloud compute instances list
```

## Configuring SSH Access

Test SSH access to the `controller-0` compute instances:

```bash
gcloud compute ssh controller-0

...
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/username/.ssh/google_compute_engine.
Your public key has been saved in /home/username/.ssh/google_compute_engine.pub.
...

exit #from controller-0
```



#04 Provisioning a CA and Generating TLS Certificates

## Certificate Authority

In this section you will provision a Certificate Authority that can be used to generate additional TLS certificates.

Generate the CA configuration file, certificate, and private key:

```bash
cd kubernetes/the_hard_way

{
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "RU",
      "L": "SPb",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "SPb"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
}
```

Results:

```bash
ls -1 ca-*.json
ca-config.json
ca-csr.json

ls -1 ca*{*.pem,*.csr}
ca.csr
ca-key.pem
ca.pem

```

## Client and Server Certificates

### The Admin Client Certificate

Generate the `admin` client certificate and private key:

```bash
{
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "RU",
      "L": "SPb",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "SPb"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
}
```

Results:

```bash
ls -1 admin*
admin.csr
admin-csr.json
admin-key.pem
admin.pem

```

### The Kubelet Client Certificates

Generate a certificate and private key **for each** Kubernetes worker node:

У меня только 1 рабочая нода, генерю для всех нод, применять буду только для одной ноды

```bash
for instance in worker-0 worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "RU",
      "L": "SPb",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "SPb"
    }
  ]
}
EOF

EXTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')


INTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].networkIP)')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done
```

> При генерации возникли ошибки в связи с отсутствием нод:
>
> ERROR: (gcloud.compute.instances.describe) Could not fetch resource:
>
> The resource 'projects/docker-otus-201905/zones/europe-west1-c/instances/worker-1' was not found

Results:

```bash
ls -1 worker-*
worker-0.csr
worker-0-csr.json
worker-0-key.pem
worker-0.pem
worker-1.csr
worker-1-csr.json
worker-1-key.pem
worker-1.pem
worker-2.csr
worker-2-csr.json
worker-2-key.pem
worker-2.pem

```

### The Controller Manager Client Certificate

Generate the `kube-controller-manager` client certificate and private key:

```bash
{
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "RU",
      "L": "SPb",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "SPb"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
}
```



Results:

```bash
ls -1 kube-controller-manager*
kube-controller-manager.csr
kube-controller-manager-csr.json
kube-controller-manager-key.pem
kube-controller-manager.kubeconfig
kube-controller-manager.pem

```

### The Kube Proxy Client Certificate

Generate the `kube-proxy` client certificate and private key:

```bash
{
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "RU",
      "L": "SPb",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "SPb"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
}
```

Results:

```bash
ls -1 kube-proxy*
kube-proxy.csr
kube-proxy-csr.json
kube-proxy-key.pem
kube-proxy.pem

```



### The Scheduler Client Certificate

Generate the `kube-scheduler` client certificate and private key:

```bash
{
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "RU",
      "L": "SPb",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "SPb"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
}
```

Results:

```bash
ls -1 kube-scheduler*
kube-scheduler.csr
kube-scheduler-csr.json
kube-scheduler-key.pem
kube-scheduler.pem

```

### The Kubernetes API Server Certificate

Generate the Kubernetes API Server certificate and private key:

```bash
{
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "RU",
      "L": "SPb",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "SPb"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
}
```

Results:

```bash
ls -1 kubernetes*
kubernetes.csr
kubernetes-csr.json
kubernetes-key.pem
kubernetes.pem
```

## The Service Account Key Pair

Generate the `service-account` certificate and private key:

```bash
{
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "RU",
      "L": "SPb",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "SPb"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
}
```

Results:

```bash
ls -1 service-account*
service-account.csr
service-account-csr.json
service-account-key.pem
service-account.pem

```

## 

## Distribute the Client and Server Certificates

Copy the appropriate certificates and private keys to each worker instance:

```bash
for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done
```

> Ошибка, т.к. ноды не все у меня
>
> ERROR: (gcloud.compute.scp) Could not fetch resource:
>
> The resource 'projects/docker-otus-201905/zones/europe-west1-c/instances/worker-1' was not found

Copy the appropriate certificates and private keys to each controller instance:

```bash
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ${instance}:~/
done
```



#05 Generating Kubernetes Configuration Files for Authentication

## Client Authentication Configs

### Kubernetes Public IP Address

To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

```bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
```

### The kubelet Kubernetes Configuration File

Generate a kubeconfig file for each worker node:

```bash
for instance in worker-0 worker-1 worker-2; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
```

Results:

```bash
ls -1 worker-*kubeconfig
worker-0.kubeconfig
worker-1.kubeconfig
worker-2.kubeconfig

```

### The kube-proxy Kubernetes Configuration File

Generate a kubeconfig file for the `kube-proxy` service:

```bash
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}
```

Results:

```bash
ls -1 kube-proxy*kubeconfig
kube-proxy.kubeconfig

```



### The kube-controller-manager Kubernetes Configuration File

Generate a kubeconfig file for the `kube-controller-manager` service:

```bash
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}
```

Results:

```bash
ls -1 kube-controller-manager*kubeconfig
kube-controller-manager.kubeconfig

```

### 

### The kube-scheduler Kubernetes Configuration File

Generate a kubeconfig file for the `kube-scheduler` service:

```
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}
```

Results:

```bash
ls -1 kube-scheduler*kubeconfig
kube-scheduler.kubeconfig
```

### 

### The admin Kubernetes Configuration File

Generate a kubeconfig file for the `admin` user:

```bash
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}
```

Results:

```bash
ls -1 admin*kubeconfig
admin.kubeconfig
```

## Distribute the Kubernetes Configuration Files

Copy the appropriate `kubelet` and `kube-proxy` kubeconfig files to each worker instance:

```bash
for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done
```

> Ошибки в связи с отсутствием нод:
>
> ERROR: (gcloud.compute.scp) Could not fetch resource:
>
> The resource 'projects/docker-otus-201905/zones/europe-west1-c/instances/worker-1' was not found

Copy the appropriate `kube-controller-manager` and `kube-scheduler` kubeconfig files to each controller instance:

```bash
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:~/
done
```



#06 Generating the Data Encryption Config and Key

In this lab you will generate an encryption key and an [encryption config](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#understanding-the-encryption-at-rest-configuration) suitable for encrypting Kubernetes Secrets.

## The Encryption Key

Generate an encryption key:

```bash
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

## The Encryption Config File

Create the `encryption-config.yaml` encryption config file:

```bash
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

Copy the `encryption-config.yaml` encryption config file to each controller instance:

```bash
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp encryption-config.yaml ${instance}:~/
done
```



# 07 Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/coreos/etcd). 

## Prerequisites

The commands in this lab must be **run on each controller** instance: `controller-0`, `controller-1`, and `controller-2`. 

```bash
gcloud compute ssh controller-0
```

## Bootstrapping an etcd Cluster Member

###Download and Install the etcd Binaries

Download the official etcd release binaries from the [coreos/etcd](https://github.com/coreos/etcd) GitHub project:

```bash
wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz"
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```bash
{
  tar -xvf etcd-v3.3.9-linux-amd64.tar.gz
  sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
}
```

###Configure the etcd Server

```bash
{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
}
```

The instance internal IP address will be used to serve client  requests and communicate with etcd cluster peers. Retrieve the internal  IP address for the current compute instance:

```bash
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
```

Each etcd member must have a unique name within an etcd cluster. Set  the etcd name to match the hostname of the current compute instance:

```bash
ETCD_NAME=$(hostname -s)
```

Create the `etcd.service` systemd unit file:

```bash
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

###### Start the etcd Server

```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}
```

> Remember to run the above commands on each controller node: `controller-0`, `controller-1`, and `controller-2`.

## Verification

List the etcd cluster members:

```bash
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

> output

```
3a57933972cb5131, started, controller-2, https://10.240.0.12:2380, https://10.240.0.12:2379
f98dc20bce6225a0, started, controller-0, https://10.240.0.10:2380, https://10.240.0.10:2379
ffed16798470cab5, started, controller-1, https://10.240.0.11:2380, https://10.240.0.11:2379

```



#08 Bootstrapping the Kubernetes Control Plane

## Prerequisites

The commands in this lab must be **run on each controller** instance: `controller-0`, `controller-1`, and `controller-2`. 

```bash
gcloud compute ssh controller-0
```

## Provision the Kubernetes Control Plane

Create the Kubernetes configuration directory:

```bash
sudo mkdir -p /etc/kubernetes/config
```

###Download and Install the Kubernetes Controller Binaries

Download the official Kubernetes release binaries:

```bash
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl"
```

Install the Kubernetes binaries:

```bash
{
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
}
```

### Configure the Kubernetes API Server

```bash
{
  sudo mkdir -p /var/lib/kubernetes/

  sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
}
```

The instance internal IP address will be used to advertise the API  Server to members of the cluster. 

```bash
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
```

Create the `kube-apiserver.service` systemd unit file:

```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 

### Configure the Kubernetes Controller Manager

Move the `kube-controller-manager` kubeconfig into place:

```bash
sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
```

Create the `kube-controller-manager.service` systemd unit file:

```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Scheduler

Move the `kube-scheduler` kubeconfig into place:

```bash
sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
```

Create the `kube-scheduler.yaml` configuration file:

```bash
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
```

Create the `kube-scheduler.service` systemd unit file:

```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the Controller Services

```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
  sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
}
```

> Allow up to 10 seconds for the Kubernetes API Server to fully initialize.



### Enable HTTP Health Checks

Устанавливается на каждом контроллере

```bash
sudo apt-get install -y nginx


cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF


{
  sudo mv kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-available/kubernetes.default.svc.cluster.local

  sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
}


sudo systemctl restart nginx
sudo systemctl enable nginx

```

### Verification

```bash
kubectl get componentstatuses --kubeconfig admin.kubeconfig


NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}

```

Test the nginx HTTP health check proxy:

```bash
curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz


HTTP/1.1 200 OK
Server: nginx/1.14.0 (Ubuntu)
Date: Fri, 14 Jun 2019 19:58:11 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive

```

## RBAC for Kubelet Authorization

RBAC permissions to allow the Kubernetes API Server to access the Kubelet API on each worker node

Access to the Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

```bash
gcloud compute ssh controller-0
```

Create the `system:kube-apiserver-to-kubelet` [ClusterRole](https://kubernetes.io/docs/admin/authorization/rbac/#role-and-clusterrole) with permissions to access the Kubelet API and perform most common tasks associated with managing pods:

На любой ноде кластера контроллера, т.к. это кластерная роль.

```bash
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

Bind the `system:kube-apiserver-to-kubelet` ClusterRole to the `kubernetes` user:

```bash
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

## The Kubernetes Frontend Load Balancer

Provision an external load balancer to front the Kubernetes API Servers. The `kubernetes-the-hard-way` static IP address will be attached to the resulting load balancer.

### Provision a Network Load Balancer

Create the external load balancer network resources:

!!! В опцию --source-ranges подставил IP своей машины

```bash
{
  KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')

  gcloud compute http-health-checks create kubernetes \
    --description "Kubernetes Health Check" \
    --host "kubernetes.default.svc.cluster.local" \
    --request-path "/healthz"

  gcloud compute firewall-rules create kubernetes-the-hard-way-allow-health-check \
    --network kubernetes-the-hard-way \
    --source-ranges 188.242.0.0/16 \
    --allow tcp

  gcloud compute target-pools create kubernetes-target-pool \
    --http-health-check kubernetes

  gcloud compute target-pools add-instances kubernetes-target-pool \
   --instances controller-0,controller-1,controller-2

  gcloud compute forwarding-rules create kubernetes-forwarding-rule \
    --address ${KUBERNETES_PUBLIC_ADDRESS} \
    --ports 6443 \
    --region $(gcloud config get-value compute/region) \
    --target-pool kubernetes-target-pool
}
```

### Verification

Retrieve the `kubernetes-the-hard-way` static IP address:

```bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
```

Make a HTTP request for the Kubernetes version info:

```bash
cd kubernetes/the_hard_way

curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version
```

> output

```json
{
  "major": "1",
  "minor": "12",
  "gitVersion": "v1.12.0",
  "gitCommit": "0ed33881dc4355495f623c6f22e7dd0b7632b7c0",
  "gitTreeState": "clean",
  "buildDate": "2018-09-27T16:55:41Z",
  "goVersion": "go1.10.4",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```



#09 Bootstrapping the Kubernetes Worker Nodes

The following components will be installed on each node: [runc](https://github.com/opencontainers/runc), [gVisor](https://github.com/google/gvisor), [container networking plugins](https://github.com/containernetworking/cni), [containerd](https://github.com/containerd/containerd), [kubelet](https://kubernetes.io/docs/admin/kubelet), and [kube-proxy](https://kubernetes.io/docs/concepts/cluster-administration/proxies).

## Prerequisites

The commands in this lab must be run on each worker instance: `worker-0`, `worker-1`, and `worker-2`.

!!! У меняя только одна рабочая нода, поэтому выполнять буду только там.

```bash
gcloud compute ssh worker-0
```

## Provisioning a Kubernetes Worker Node

Install the OS dependencies:

```bash
{
  sudo apt-get update
  sudo apt-get -y install socat conntrack ipset
}
```

> The socat binary enables support for the `kubectl port-forward` command.

### Download and Install Worker Binaries

```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.12.0/crictl-v1.12.0-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-the-hard-way/runsc-50c283b9f56bb7200938d9e207355f05f79f0d17 \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
  https://github.com/containerd/containerd/releases/download/v1.2.0-rc.0/containerd-1.2.0-rc.0.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubelet
  
```

Create the installation directories:

```bash
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
  
```

Install the worker binaries:

```bash
{
  sudo mv runsc-50c283b9f56bb7200938d9e207355f05f79f0d17 runsc
  sudo mv runc.amd64 runc
  chmod +x kubectl kube-proxy kubelet runc runsc
  sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
  sudo tar -xvf crictl-v1.12.0-linux-amd64.tar.gz -C /usr/local/bin/
  sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
  sudo tar -xvf containerd-1.2.0-rc.0.linux-amd64.tar.gz -C /
}
```

### Configure CNI Networking

Retrieve the Pod CIDR range for the current compute instance:

```bash
POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)
```

Create the `bridge` network configuration file:

```bash
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```

Create the `loopback` network configuration file:

```bash
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF
```

### Configure containerd

Create the `containerd` configuration file:

```bash
sudo mkdir -p /etc/containerd/


cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
    [plugins.cri.containerd.gvisor]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
EOF

```

> Untrusted workloads will be run using the gVisor (runsc) runtime.

Create the `containerd.service` systemd unit file:

```bash
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

```

### Configure the Kubelet

```bash
{
  sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  sudo mv ca.pem /var/lib/kubernetes/
}
```

Create the `kubelet-config.yaml` configuration file:

```bash
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

```

> The `resolvConf` configuration is used to avoid loops when using CoreDNS for service discovery on systems running `systemd-resolved`.

Create the `kubelet.service` systemd unit file:

```bash
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

```

### Configure the Kubernetes Proxy

```bash
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```

Create the `kube-proxy-config.yaml` configuration file:

```bash
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

```

Create the `kube-proxy.service` systemd unit file:

```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

```

### Start the Worker Services

```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable containerd kubelet kube-proxy
  sudo systemctl start containerd kubelet kube-proxy
}
```

> Remember to run the above commands on each worker node: `worker-0`, `worker-1`, and `worker-2`.

## Verification

List the registered Kubernetes nodes:

!!! Со своего ПК с gcloud

```bash
gcloud compute ssh controller-0 \
  --command "kubectl get nodes --kubeconfig admin.kubeconfig"
```

> output

```bash
NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   19s   v1.12.0

# !!! д.б. 3 рабочих ноды, но у меня лимит в 4 ноды: 3 контроллера + 1 рабочая нода
```



# 10 Configuring kubectl for Remote Access

Generate a kubeconfig file for the `kubectl` command line utility based on the `admin` user.

Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

Generate a kubeconfig file suitable for authenticating as the `admin` user:

!!! Выполняется на ПК, во 2й теме на него установили `kubectl` 

```bash
{
  KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}
```

List the nodes in the remote Kubernetes cluster:

```bash
kubectl get nodes
```

> output

```rst
NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   57s   v1.12.0

# !!! д.б. 3 рабочих ноды, но у меня лимит в 4 ноды: 3 контроллера + 1 рабочая нода
```



#11 Provisioning Pod Network Routes

Create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address. Because pods can not communicate with other pods running on different nodes due to missing network routes.

## The Routing Table

Print the internal IP address and Pod CIDR range for each worker instance:

```bash
for instance in worker-0 worker-1 worker-2; do
  gcloud compute instances describe ${instance} \
    --format 'value[separator=" "](networkInterfaces[0].networkIP,metadata.items[0].value)'
done
```

> output

```bash
10.240.0.20 10.200.0.0/24
ERROR: (gcloud.compute.instances.describe) Could not fetch resource:
 - The resource 'projects/docker-otus-201905/zones/europe-west1-c/instances/worker-1' was not found

ERROR: (gcloud.compute.instances.describe) Could not fetch resource:
 - The resource 'projects/docker-otus-201905/zones/europe-west1-c/instances/worker-2' was not found
```

## Routes

Create network routes for each worker instance:

```bash
for i in 0; do
  gcloud compute routes create kubernetes-route-10-200-${i}-0-24 \
    --network kubernetes-the-hard-way \
    --next-hop-address 10.240.0.2${i} \
    --destination-range 10.200.${i}.0/24
done

# !!! т.к. у меня одна рабочая нода, то нужно
# - либо исправить вверху в скрипте "for i in 0 1 2; do" на "for i in 0; do" до его выполнения
# - либо удалить потом лишние маршруты
# gcloud compute routes delete kubernetes-route-10-200-1-0-24
# gcloud compute routes delete kubernetes-route-10-200-2-0-24

```

List the routes in the `kubernetes-the-hard-way` VPC network:

```bash
gcloud compute routes list --filter "network: kubernetes-the-hard-way"
```

> output

```rst
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP                  PRIORITY
default-route-74b82434a479b920  kubernetes-the-hard-way  10.240.0.0/24  kubernetes-the-hard-way   1000
default-route-fb3c803506a2f9c1  kubernetes-the-hard-way  0.0.0.0/0      default-internet-gateway  1000
kubernetes-route-10-200-0-0-24  kubernetes-the-hard-way  10.200.0.0/24  10.240.0.20               1000

```



#12 Deploying the DNS Cluster Add-on

Deploy the [DNS add-on](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) which provides DNS based service discovery, backed by [CoreDNS](https://coredns.io/), to applications running inside the Kubernetes cluster

## The DNS Cluster Add-on

Deploy the `coredns` cluster add-on:

```bash
kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml
```

> output

```
serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.extensions/coredns created
service/kube-dns created
```

List the pods created by the `kube-dns` deployment:

```bash
kubectl get pods -l k8s-app=kube-dns -n kube-system -o wide
```

> output

```rst
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE
coredns-699f8ddd77-kk7br   1/1     Running   0          11s   10.200.0.3   worker-0   <none>
coredns-699f8ddd77-rnt2h   1/1     Running   0          11s   10.200.0.2   worker-0   <none>
```

## Verification

Create a `busybox` deployment:

```bash
kubectl run busybox --image=busybox:1.28 --command -- sleep 3600
```

List the pod created by the `busybox` deployment:

```bash
kubectl get pods -l run=busybox
```

> output

```rst
NAME                      READY   STATUS    RESTARTS   AGE
busybox-bd8fb7cbd-87fqt   1/1     Running   0          8s
```

Retrieve the full name of the `busybox` pod:

```bash
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
```

Execute a DNS lookup for the `kubernetes` service inside the `busybox` pod:

```bash
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```

> output

```rst
Server:    10.32.0.10
Address 1: 10.32.0.10

nslookup: can't resolve 'kubernetes'
command terminated with exit code 1
```



```bash
# если обратиться к ноде, на которой непосредственно развернут coredns, то все ок
kubectl exec -ti $POD_NAME -- nslookup kubernetes 10.200.0.2
Server:    10.200.0.2
Address 1: 10.200.0.2 10-200-0-2.kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local
```

-=-=-=-=-=-=-=-=

### РАСЛЕДОВАНИЕ, пока не удачно

Подобной ошибки для этой руководства в интернете полно

https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/254

https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

```bash
kubectl delete -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml
kubectl apply -f  https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml

kubectl get service --all-namespaces
NAMESPACE     NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
default       kubernetes   ClusterIP   10.32.0.1    <none>        443/TCP         16h
kube-system   kube-dns     ClusterIP   10.32.0.10   <none>        53/UDP,53/TCP   116m



kubectl get pods -l k8s-app=kube-dns -n kube-system -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE
coredns-699f8ddd77-gmm7v   1/1     Running   0          13m   10.200.0.8   worker-0   <none>
coredns-699f8ddd77-qczn2   1/1     Running   0          13m   10.200.0.7   worker-0   <none>


kubectl describe pod -n kube-system coredns-699f8ddd77-kk7br
...
Events:
  Type    Reason     Age    From               Message
  ----    ------     ----   ----               -------
  Normal  Scheduled  3m5s   default-scheduler  Successfully assigned kube-system/coredns-699f8ddd77-kk7br to worker-0
  Normal  Pulling    3m     kubelet, worker-0  pulling image "coredns/coredns:1.2.2"
  Normal  Pulled     2m57s  kubelet, worker-0  Successfully pulled image "coredns/coredns:1.2.2"
  Normal  Created    2m57s  kubelet, worker-0  Created container
  Normal  Started    2m57s  kubelet, worker-0  Started container


kubectl get pods -n default
NAME                      READY   STATUS    RESTARTS   AGE
busybox-bd8fb7cbd-87fqt   1/1     Running   0          3m8s


kubectl exec busybox-bd8fb7cbd-87fqt cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local europe-west1-c.c.docker-otus-201905.internal c.docker-otus-201905.internal google.internal
nameserver 10.32.0.10
options ndots:5


for p in $(kubectl get pods --namespace=kube-system -l k8s-app=kube-dns -o name); do kubectl logs --namespace=kube-system $p; done
.:53
2019/06/14 20:08:21 [INFO] CoreDNS-1.2.2
2019/06/14 20:08:21 [INFO] linux/amd64, go1.11, eb51e8b
CoreDNS-1.2.2
linux/amd64, go1.11, eb51e8b
2019/06/14 20:08:21 [INFO] plugin/reload: Running configuration MD5 = 2e2180a5eeb3ebf92a5100ab081a6381
.:53
2019/06/14 20:08:21 [INFO] CoreDNS-1.2.2
2019/06/14 20:08:21 [INFO] linux/amd64, go1.11, eb51e8b
CoreDNS-1.2.2
linux/amd64, go1.11, eb51e8b
2019/06/14 20:08:21 [INFO] plugin/reload: Running configuration MD5 = 2e2180a5eeb3ebf92a5100ab081a6381


kubectl get svc --namespace=kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   ClusterIP   10.32.0.10   <none>        53/UDP,53/TCP   4m48s


kubectl get ep kube-dns --namespace=kube-system
NAME       ENDPOINTS                                               AGE
kube-dns   10.200.0.2:53,10.200.0.3:53,10.200.0.2:53 + 1 more...   5m1s


kubectl -n kube-system edit configmap coredns
добавить строку с log, сот сюда
----------
apiVersion: v1
data:
  Corefile: |
    .:53 {
        log       <- сюда
        errors
        health
...
----------
подождать пару минут и посмотреть логи
for p in $(kubectl get pods --namespace=kube-system -l k8s-app=kube-dns -o name); do kubectl logs --namespace=kube-system $p; done

```



```bash
kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools
```



```bash
#add line: --resolv-conf=/run/systemd/resolve/resolv.conf \\
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --resolv-conf=/run/systemd/resolve/resolv.conf \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


{
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
}

sudo systemctl restart containerd kubelet kube-proxy
```



# 13 Smoke Test

## Data Encryption

In this section you will verify the ability to [encrypt secret data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted).

Create a generic secret:

```bash
kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"
```

Print a hexdump of the `kubernetes-the-hard-way` secret stored in etcd:

```
gcloud compute ssh controller-0 \
  --command "sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem\
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"
```

> output

```rst
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
00000040  3a 76 31 3a 6b 65 79 31  3a ef c3 c7 85 37 90 96  |:v1:key1:....7..|
00000050  14 d1 2d 08 88 ec e9 f2  f4 e8 9a 90 a8 61 0e 67  |..-..........a.g|
00000060  b0 a8 ab e4 b7 71 57 50  c0 11 3a d9 9f 17 8b dd  |.....qWP..:.....|
00000070  8c 86 e1 15 be 59 c0 29  64 b4 05 67 5d fa 1d 53  |.....Y.)d..g]..S|
00000080  c1 59 f5 1d 69 51 f1 a7  ea 15 fb 1a f0 e4 24 89  |.Y..iQ........$.|
00000090  f3 fb 9c 27 b8 2f b9 cc  3c 53 d8 c8 e4 3e f9 e6  |...'./..<S...>..|
000000a0  62 7f 26 b3 9b db 93 57  b4 62 67 6c dd 87 43 8a  |b.&....W.bgl..C.|
000000b0  93 c7 b1 da 74 63 ad 41  eb c7 81 ae dc 91 f8 f5  |....tc.A........|
000000c0  0e 29 38 7e df ec 95 cb  00 81 01 cf be 83 36 9f  |.)8~..........6.|
000000d0  ef 5c c7 25 82 dc 1d 21  07 cb 2b 06 ba 03 9d a1  |.\.%...!..+.....|
000000e0  11 a5 1b 92 b8 79 05 73  b3 0a                    |.....y.s..|
000000ea

```

The etcd key should be prefixed with `k8s:enc:aescbc:v1:key1`, which indicates the `aescbc` provider was used to encrypt the data with the `key1` encryption key.

## Deployments

In this section you will verify the ability to create and manage [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

Create a deployment for the [nginx](https://nginx.org/en/) web server:

```
kubectl run nginx --image=nginx
```

List the pod created by the `nginx` deployment:

```bash
kubectl get pods -l run=nginx
```

> output

```rst
NAME                    READY   STATUS              RESTARTS   AGE
nginx-dbddb74b8-mrs88   0/1     ContainerCreating   0          6s

```

### Port Forwarding

In this section you will verify the ability to access applications remotely using [port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).

Retrieve the full name of the `nginx` pod:

```bash
POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")
```

Forward port `8080` on your local machine to port `80` of the `nginx` pod:

```bash
kubectl port-forward $POD_NAME 8080:80
```

> output

```rst
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
```

In a new terminal make an HTTP request using the forwarding address:

!!! Пробрасывается на мой ПК

```bash
curl --head http://127.0.0.1:8080
```

> output

```rst
HTTP/1.1 200 OK
Server: nginx/1.17.0
Date: Fri, 14 Jun 2019 20:26:35 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 21 May 2019 14:23:57 GMT
Connection: keep-alive
ETag: "5ce409fd-264"
Accept-Ranges: bytes
```

Switch back to the previous terminal and stop the port forwarding to the `nginx` pod:

```bash
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
Handling connection for 8080
^C
```

### Logs

In this section you will verify the ability to [retrieve container logs](https://kubernetes.io/docs/concepts/cluster-administration/logging/).

Print the `nginx` pod logs:

```bash
kubectl logs $POD_NAME
```

> output

```rst
127.0.0.1 - - [14/Jun/2019:20:26:35 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.58.0" "-"
```

### Exec

In this section you will verify the ability to [execute commands in a container](https://kubernetes.io/docs/tasks/debug-application-cluster/get-shell-running-container/#running-individual-commands-in-a-container).

Print the nginx version by executing the `nginx -v` command in the `nginx` container:

```bash
kubectl exec -ti $POD_NAME -- nginx -v
```

> output

```rst
nginx version: nginx/1.17.0
```

## Services

In this section you will verify the ability to expose applications using a [Service](https://kubernetes.io/docs/concepts/services-networking/service/).

Expose the `nginx` deployment using a [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) service:

```bash
kubectl expose deployment nginx --port 80 --type NodePort
```

!!! --port 80 - это порт внутри контейнера, внешний будет другой

> The LoadBalancer service type can not be used because your cluster is not configured with [cloud provider integration](https://kubernetes.io/docs/getting-started-guides/scratch/#cloud-provider). Setting up cloud provider integration is out of scope for this tutorial.

Retrieve the node port assigned to the `nginx` service:

```bash
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')

echo $NODE_PORT
#--------------
31058

```

Create a firewall rule that allows remote access to the `nginx` node port:

```bash
gcloud compute firewall-rules create kubernetes-the-hard-way-allow-nginx-service \
  --allow=tcp:${NODE_PORT} \
  --network kubernetes-the-hard-way
```

Retrieve the external IP address of a worker instance:

```bash
EXTERNAL_IP=$(gcloud compute instances describe worker-0 \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

echo $EXTERNAL_IP
#-----------------
34.77.53.101
```

Make an HTTP request using the external IP address and the `nginx` node port:

```bash
curl -I http://${EXTERNAL_IP}:${NODE_PORT}
```

> output

```rst
HTTP/1.1 200 OK
Server: nginx/1.17.0
Date: Fri, 14 Jun 2019 20:28:57 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 21 May 2019 14:23:57 GMT
Connection: keep-alive
ETag: "5ce409fd-264"
Accept-Ranges: bytes

```

## Untrusted Workloads

This section will verify the ability to run untrusted workloads using [gVisor](https://github.com/google/gvisor).

Create the `untrusted` pod:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: untrusted
  annotations:
    io.kubernetes.cri.untrusted-workload: "true"
spec:
  containers:
    - name: webserver
      image: gcr.io/hightowerlabs/helloworld:2.0.0
EOF
```

### Verification

In this section you will verify the `untrusted` pod is running under gVisor (runsc) by inspecting the assigned worker node.

Verify the `untrusted` pod is running:

```bash
kubectl get pods -o wide
NAME                      READY   STATUS    RESTARTS   AGE    IP           NODE       NOMINATED NODE
busybox-bd8fb7cbd-87fqt   1/1     Running   0          20m    10.200.0.4   worker-0   <none>
nginx-dbddb74b8-mrs88     1/1     Running   0          5m4s   10.200.0.5   worker-0   <none>
untrusted                 1/1     Running   0          9s     10.200.0.6   worker-0   <none>

```

Get the node name where the `untrusted` pod is running:

```bash
INSTANCE_NAME=$(kubectl get pod untrusted --output=jsonpath='{.spec.nodeName}')

echo $INSTANCE_NAME
#-------------------
worker-0

```

SSH into the worker node:

```bash
gcloud compute ssh ${INSTANCE_NAME}
```

List the containers running under gVisor:

```bash
sudo runsc --root  /run/containerd/runsc/k8s.io list
I0614 20:30:08.318592    6645 x:0] ***************************
I0614 20:30:08.318789    6645 x:0] Args: [runsc --root /run/containerd/runsc/k8s.io list]
I0614 20:30:08.318879    6645 x:0] Git Revision: 50c283b9f56bb7200938d9e207355f05f79f0d17
I0614 20:30:08.318940    6645 x:0] PID: 6645
I0614 20:30:08.318997    6645 x:0] UID: 0, GID: 0
I0614 20:30:08.319045    6645 x:0] Configuration:
I0614 20:30:08.319090    6645 x:0]              RootDir: /run/containerd/runsc/k8s.io
I0614 20:30:08.319183    6645 x:0]              Platform: ptrace
I0614 20:30:08.319281    6645 x:0]              FileAccess: exclusive, overlay: false
I0614 20:30:08.319379    6645 x:0]              Network: sandbox, logging: false
I0614 20:30:08.319473    6645 x:0]              Strace: false, max size: 1024, syscalls: []
I0614 20:30:08.319566    6645 x:0] ***************************
ID                                                                 PID         STATUS      BUNDLE                                                                                                                   CREATED                OWNER
315f48d3a072d139f02fb9e59cf116106352772090264560ccc900274a9d71fc   6344        running     /run/containerd/io.containerd.runtime.v1.linux/k8s.io/315f48d3a072d139f02fb9e59cf116106352772090264560ccc900274a9d71fc   0001-01-01T00:00:00Z
7b3151785fda862214077dc0c9e2212a956d28db981480f271c1d5f82134f417   6403        running     /run/containerd/io.containerd.runtime.v1.linux/k8s.io/7b3151785fda862214077dc0c9e2212a956d28db981480f271c1d5f82134f417   0001-01-01T00:00:00Z
I0614 20:30:08.322818    6645 x:0] Exiting with status: 0

```

Get the ID of the `untrusted` pod:

```bash
POD_ID=$(sudo crictl -r unix:///var/run/containerd/containerd.sock \
  pods --name untrusted -q)

echo $POD_ID
#------------
eab908f7d6ce668b5e51aa690e3e3ba20338152d198596653ed3b998584e3814
```

Get the ID of the `webserver` container running in the `untrusted` pod:

```bash
CONTAINER_ID=$(sudo crictl -r unix:///var/run/containerd/containerd.sock \
  ps -p ${POD_ID} -q)

echo $CONTAINER_ID
#------------------
2aee5cc26672ecda8d6062279f6293fdf9cefa3e0e1386cb46e28f55837a8183
```

Use the gVisor `runsc` command to display the processes running inside the `webserver` container:

```bash
sudo runsc --root /run/containerd/runsc/k8s.io ps ${CONTAINER_ID}
```

> output

```rst
I0614 20:30:42.991566    6724 x:0] ***************************
I0614 20:30:42.991746    6724 x:0] Args: [runsc --root /run/containerd/runsc/k8s.io ps 7b3151785fda862214077dc0c9e2212a956d28db981480f271c1d5f82134f417]
I0614 20:30:42.991919    6724 x:0] Git Revision: 50c283b9f56bb7200938d9e207355f05f79f0d17
I0614 20:30:42.991971    6724 x:0] PID: 6724
I0614 20:30:42.992023    6724 x:0] UID: 0, GID: 0
I0614 20:30:42.992071    6724 x:0] Configuration:
I0614 20:30:42.992115    6724 x:0]              RootDir: /run/containerd/runsc/k8s.io
I0614 20:30:42.992216    6724 x:0]              Platform: ptrace
I0614 20:30:42.992316    6724 x:0]              FileAccess: exclusive, overlay: false
I0614 20:30:42.992410    6724 x:0]              Network: sandbox, logging: false
I0614 20:30:42.992513    6724 x:0]              Strace: false, max size: 1024, syscalls: []
I0614 20:30:42.992619    6724 x:0] ***************************
UID       PID       PPID      C         STIME     TIME      CMD
0         1         0         0         20:29     10ms      app
I0614 20:30:42.994090    6724 x:0] Exiting with status: 0

```



```bash
# exit from worker-0
exit
```



# ЗАПУСК ПОДОВ С ДЗ №25

```bash
cd kubernetes/reddit

kubectl apply -f comment-deployment.yml
kubectl apply -f mongo-deployment.yml
kubectl apply -f post-deployment.yml
kubectl apply -f ui-deployment.yml

```

## Проверка

```bash
kubectl get pods -n default|grep -iE "ui|post|comment|mongo|name"


NAME                                  READY   STATUS    RESTARTS   AGE
comment-deployment-7f6d74b44f-bq5rg   1/1     Running   0          61s
mongo-deployment-67f58fb89-dxc4n      1/1     Running   0          61s
post-deployment-7bbd85f579-978bw      1/1     Running   0          61s
ui-deployment-bffdc68c5-nf5tt         1/1     Running   0          75s

```



# 14 Cleaning Up

In this lab you will delete the compute resources created during this tutorial.

## Compute Instances

Delete the controller and worker compute instances:

```bash
gcloud -q compute instances delete \
  controller-0 controller-1 controller-2 \
  worker-0 worker-1 worker-2
```

## Networking

Delete the external load balancer network resources:

```bash
{
  gcloud -q compute forwarding-rules delete kubernetes-forwarding-rule \
    --region $(gcloud config get-value compute/region)
  gcloud -q compute target-pools delete kubernetes-target-pool
  gcloud -q compute http-health-checks delete kubernetes
  gcloud -q compute addresses delete kubernetes-the-hard-way
}
```

Delete the `kubernetes-the-hard-way` firewall rules:

```bash
gcloud -q compute firewall-rules delete \
  kubernetes-the-hard-way-allow-nginx-service \
  kubernetes-the-hard-way-allow-internal \
  kubernetes-the-hard-way-allow-external \
  kubernetes-the-hard-way-allow-health-check
```

Delete the `kubernetes-the-hard-way` network VPC:

```bash
{
  gcloud -q compute routes delete \
    kubernetes-route-10-200-0-0-24 \
    kubernetes-route-10-200-1-0-24 \
    kubernetes-route-10-200-2-0-24

  gcloud -q compute networks subnets delete kubernetes

  gcloud -q compute networks delete kubernetes-the-hard-way
}
```





























# ВОПРОСЫ

- 03

  Each worker instance requires a pod subnet allocation from the  Kubernetes cluster CIDR range. The pod subnet allocation will be used to  configure container networking in a later exercise. The `pod-cidr` instance metadata will be used to expose pod subnet allocations to compute instances at runtime.

  > The Kubernetes cluster CIDR range is defined by the Controller Manager's `--cluster-cidr` flag. In this tutorial the cluster CIDR range will be set to `10.200.0.0/16`, which supports 254 subnets.

  ОТВЕТ:

  В 9 и 11й темах эта сеть используется для настройки сети на воркерах.

  Создание маршрутов, чтобы под с одного узла могли взаимоде1йствовать с подом др узла. Маршрут создается для каждого рабочего узла, который сопоставляет диапазон CIDR Pod узла с внутренним IP-адресом узла.

  По сути, это сеть подов.

  

- 04

  Generate the Kubernetes API Server certificate and private key

  -hostname=10.32.0.1

  ОТВЕТ:

  В 8-й теме эта сеть используется в сервисах kube-apiserver, kube-controller-manager:  ` --service-cluster-ip-range=10.32.0.0/24 \\`

  

