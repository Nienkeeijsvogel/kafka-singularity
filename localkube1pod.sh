sudo su
sudo yum update -y && \
     sudo yum groupinstall -y 'Development Tools' && \
     sudo yum install -y \
     openssl-devel \
     libuuid-devel \
     libseccomp-devel \
     wget \
     squashfs-tools \
     git \
     socat \
     cryptsetup  && \
yum install -y epel-release inotify-tools
yum install -y git socat singularity-runtime gcc libseccomp-devel make
yum install -y yum-utils
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker
export VERSION=1.17.6 OS=linux ARCH=amd64 
wget https://dl.google.com/go/go$VERSION.$OS-$ARCH.tar.gz 
sudo tar -C /usr/local -xzvf go$VERSION.$OS-$ARCH.tar.gz 
echo 'export GOPATH=${HOME}/go' >> ~/.bashrc && \
echo 'export PATH=/usr/local:/usr/local/go/bin:${PATH}:${GOPATH}/bin' >> ~/.bashrc && \
source ~/.bashrc && \
export VERSION=3.9.2 && # adjust this as necessary \
    wget https://github.com/sylabs/singularity/releases/download/v${VERSION}/singularity-ce-${VERSION}.tar.gz && \
    tar -xzf singularity-ce-${VERSION}.tar.gz && \
    cd singularity-ce-${VERSION} && \ 
    ./mconfig && \
    make -C ./builddir && \
    sudo make -C ./builddir install
    
git clone https://github.com/sylabs/singularity-cri.git
cd singularity-cri
git checkout tags/v1.0.0-beta.6 -b v1.0.0-beta.6
make
make install

cat <<EOF > /etc/systemd/system/sycri.service
[Unit]
Description=Singularity-CRI
After=network.target
[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=/usr/local/bin/sycri
Environment="PATH=/usr/local/libexec/singularity/bin:/usr/libexec/singularity/bin:/bin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
Environment="GOPATH=/usr/bin/go"
[Install]
WantedBy=multi-user.target
EOF

systemctl enable sycri
systemctl start sycri
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
swapoff -a
sed -e '/swap/s/^/#/g' -i /etc/fstab
lsmod | grep br_netfilter
modprobe br_netfilter

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg	 https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

yum install -y kubelet-1.21.0 kubeadm-1.21.0 kubectl-1.21.0 --disableexcludes=kubernetes
systemctl enable kubelet

cat > /etc/default/kubelet << EOF
  KUBELET_EXTRA_ARGS=--container-runtime=remote \
  --container-runtime-endpoint=unix:///var/run/singularity.sock \
  --image-service-endpoint=unix:///var/run/singularity.sock
EOF

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

cat <<EOF > local-kafka-kuber-sing.yml
apiVersion: v1
kind: Pod
metadata:
  name: kafka
spec:
  containers:
    - name: zookeeper
      image: confluentinc/cp-zookeeper:3.3.0-1
      env:
        - name: ZOOKEEPER_CLIENT_PORT
          value: "22181"
    - name: kafka-broker
      image: confluentinc/cp-kafka:4.1.2-2
      env:
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: "localhost:22181"
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://:29092"
    - name: producer
      image: neijsvogel/producer:uni
      command: ["/bin/sh"]
      args: ["-c","python /code/producer.py singularitypod 10000"]
    - name: consumer
      image: neijsvogel/consumer:uni
      command: ["/bin/sh"]
      args: ["-c","python /code/consumer.py singularitypod 10000"]
EOF

sysctl --system
systemctl stop firewalld

#commands are singularity singularitykube docker dockerpod dockerkube
#max messaging
#image is neijsvogel/consumer:universail

singularity run --env KAFKA_ZOOKEEPER_CONNECT=localhost:12181 --env KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:19092 --writable-tmpfs docker://confluentinc/cp-kafka:4.1.2-2 > /dev/null 2>&1 &
singularity run --writable-tmpfs --env ZOOKEEPER_CLIENT_PORT=12181 docker://confluentinc/cp-zookeeper:3.3.0-1 > /dev/null 2>&1 &
sleep 60
singularity exec --env TZ=Europe/Amsterdam docker://neijsvogel/producer:uni python3 /code/producer.py singularity 10000 > /dev/null 2>&1 &
singularity exec --env TZ=Europe/Amsterdam docker://neijsvogel/consumer:uni python3 /code/consumer.py singularity 10000 

#configure kubelet and apply calico cni bridge for networking
#create namespace and apply elevated memory and cpu use
kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket unix:///var/run/singularity.sock --ignore-preflight-errors=all
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
kubectl create namespace sing-kube
kubectl config set-context --current --namespace=sing-kube
kubectl taint nodes $(hostname) node-role.kubernetes.io/master-
sleep 20
kubectl apply -f local-kafka-kuber-sing.yml --namespace=sing-kube

systemctl stop kubelet
rm -f /etc/default/kubelet
systemctl enable docker.service
sudo systemctl start docker
systemctl start kubelet

docker network create kafka
docker run -p 39092:39092 --network kafka --hostname kafka --env KAFKA_ZOOKEEPER_CONNECT=zookeeper-1:32181 --env KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:39092 confluentinc/cp-kafka:4.1.2-2 > /dev/null 2>&1 &
docker run -p 32181:32181 --network kafka --env ZOOKEEPER_CLIENT_PORT='32181' --hostname zookeeper-1 confluentinc/cp-zookeeper:3.3.0-1 > /dev/null 2>&1 &
sleep 5
docker run --network kafka --env TZ=Europe/Amsterdam neijsvogel/producer:uni python /code/producer.py docker 10000 > /dev/null 2>&1 &
docker run --network kafka --env TZ=Europe/Amsterdam neijsvogel/consumer:uni python /code/consumer.py docker 10000 

cat <<EOF > local-kafka-kuber-dock.yml
apiVersion: v1
kind: Pod
metadata:
  name: kafka
spec:
  containers:
    - name: zookeeper
      image: confluentinc/cp-zookeeper:3.3.0-1
      env:
        - name: ZOOKEEPER_CLIENT_PORT
          value: "42181"
    - name: kafka-broker
      image: confluentinc/cp-kafka:4.1.2-2
      env:
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: "localhost:42181"
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://:49092"
    - name: producer
      image: neijsvogel/producer:uni
      command: ["/bin/sh"]
      args: ["-c","python /code/producer.py dockerpod 10000"]
    - name: consumer
      image: neijsvogel/consumer:uni
      command: ["/bin/sh"]
      args: ["-c","python /code/consumer.py dockerpod 10000"]
EOF


#configure kubelet and apply calico cni bridge for networking
kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=all
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
kubectl create namespace dock-kube
kubectl config set-context --current --namespace=dock-kube
kubectl taint nodes $(hostname) node-role.kubernetes.io/master-
sleep 5 
kubectl apply -f local-kafka-kuber-dock.yml --namespace=dock-kube
 
 
