#!/bin/bash

server=`minikube ssh 'sudo cat /etc/kubernetes/admin.conf | grep server' | awk '{print $2}'`
cad=`minikube ssh 'sudo cat /etc/kubernetes/admin.conf | grep certificate-authority-data' | awk '{print $2}'`
clusterName=`minikube ssh 'sudo cat /etc/kubernetes/admin.conf | grep -m 1 name' | tr -d "\r" | awk '{print $2}'`

echo "Server=$server"
echo "CAD=$cad"
echo "name=$clusterName"

create_user() {
    echo "Creating User=$1 Group=$2"

    openssl genpkey -out $1.key -algorithm ed25519

    # create certificate for user with given group
    openssl req -new -key $1.key -out $1.csr -subj "/CN=$1/O=$2"
    
    cert=`cat $1.csr | base64 | tr -d "\n"`
    
    cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $1
spec:
  request: $cert
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
  - client auth
EOF

    kubectl certificate approve $1

    kubectl get csr $1 -o jsonpath='{.status.certificate}'| base64 -d > $1.crt

    cat <<EOF > $1.kubeconfig
apiVersion: v1
clusters:
  - cluster:
      certificate-authority-data: $cad
      server: $server
    name: $clusterName
EOF
    kubectl --kubeconfig $1.kubeconfig config set-credentials $1 --client-key=$1.key --client-certificate=$1.crt --embed-certs=true
    kubectl --kubeconfig $1.kubeconfig config set-context "$1-context" --cluster=$clusterName --user=$1

}

# create users
create_user "andy_dev" "development"
create_user "kate_dev" "prodDelivery"

# create contexts
kubectl create namespace my-project-dev
kubectl create namespace my-project-prod
