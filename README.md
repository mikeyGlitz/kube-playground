# Kubernetes Cluster for Local Development

This repository contains setup and installation for a local
kubernetes cluster using minikube.

**Table of Contents**
- [Prerequistes](#prerequisites)
  - [Minikube on Windows](#minikube-on-windows)
- [Setting up load balancer](#setting-up-load-balancer)
- [Setting up ingress](#setting-up-ingress)
- [Vault](#vault)
  - [Installing Vault](#installing-vault)
  - [Writing Secrets to Vault](#writing-secrets-to-vault)
- [Service Mesh](#service-mesh)
  - [Setting up distributed tracing](#setting-up-distributed-tracing)
- [TODO](#todo)
- [References](#references)

## Prerequisites

1. Install [minikube](https://minikube.sigs.k8s.io/docs/start/)
2. Initialize minikube cluster using VM driver
```
minikube start --driver=<hyperv|virtualbox>
```
3. Install helm

```
$ brew install helm # OSX
$ snap install helm --classic # Linux Debian-based distros with Snapd
\> choco install helm // Windows with chocolatey
```

4. Install vault

```
$ brew install vault # OSX
$ snap install vault --classic # Linux Debian-based distros with Snapd
\> choco install vault // Windows with chocolatey
```

> ⚠ Helm will be auto-configured to use the kubernetes configuration
> that is set up when `minikube start` is run

### Minikube on Windows

If you're using hyperv in Windows to manage minikube,
a script has been provided [minikube-control.ps1](./minikube-control.ps1)
In order to make it easier to run minikube since hyperv requires elevated
privileges.

## Setting up load balancer

In order for ingress to work correctly a load balancer needs to be set
up. The examples in this repository use [MetalLB](https://metallb.universe.tf/installation/)
to create a local Load Balancer. An example configuration can be cound
in this repo at [metallb-configmap.yml](./metallb-configmap.yml).

## Setting up ingress

The recommended ingress for most Kubernetes applications is [ingress-nginx](https://kubernetes.github.io/ingress-nginx/).
ingress-nginx is based on the Nginx http server and proxy and is configurable
through kubernetes metadata annotations (more on that later).

If using MetalLB, you can deploy the ingress-nginx ingress controller with the following commands:

```
# Set up the ingress RBAC
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
# Set up the ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/cloud-generic.yaml
```

Alternatively, the ingress could be controlled using minikube's builtin ingress-nginx

```
minikube addons enable ingress
```

## Vault

Vault is a key-value store which is intended to store
application secrets. 

### Installing Vault

While there is an
[official helm chart](https://learn.hashicorp.com/vault/getting-started-k8s/minikube)
which can be used to install vault onto a kubernetes cluster,
this tutorial will cover installation of
[bank-vaults](https://github.com/banzaicloud/bank-vaults).
bank-vaults is a project maintained by [ banzaicloud ](https://banzaicloud.com/)
which utilizes Hashicorp Vault for secrets management.
bank-vaults provides webhooks and direct container injection for vault
secrets into Kubernetes pods

Install the helm repo

```
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
```

Create the [ vault-infra ](.bank-vaults/vault-infra.yml) namespace.

```
kubectl create -f vault-infra.yml
```

Install the vault-infra chart to the vault-infra namespace

```
helm upgrade --namespace vault-infra --install vault-operator banzaicloud-stable/vault-operator --wait
```

Create the RBAC and Cluster-Roles on the kubernetes cluster:
```
kubectl create -f ./bank-vaults/rbac.yml
kubectl create -f ./bank-vaults/cr.yml
```

#### bank-vaults Helm Chart Notes

By default the following options are enabled on vault when the helm chart is installed:
- Kubernetes authentication (being able to authenticate to vault with a 
[Kubernetes service account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) )
- PKI

### Writing secrets to vault

Get the unseal key from vault

```sh
export VAULT_TOKEN=$(kubectl get secrets vault-unseal-keys -o jsonpath={.data.vault.root} | base64 --decode)
```

> ⚠ Windows users will have to do the following due to base64 not having a Windows equivalent
>
> ```ps1
> kubectl get secrets vault-unseal-keys -o jsonpath="{data.vault.root}" > secrets.txt
> certutil -decode .\secrets.txt .\decrypted.txt
> $Env.VAULT_TOKEN=(cat decrypted.txt)
> ```

Get the ca certificate from Kubernetes

```sh
kubectl get secret vault-tls -o jsonpath="{.data.ca\.crt}" | base64 --decode > $PWD/vault-ca.crt
export VAULT_CACERT=$PWD/vault-ca.crt
```

> ⚠ Windows users will have to do the following due to base64 not having a Windows equivalent
>
> ```ps1
> kubectl get secret vault-tls -o jsonpath="{.data.ca\.crt}" > vault-ca.encrypted.crt
> certutil -decode .\vault.ca.encrypted.crt .\vault-ca.crt
> $Env.VAULT_CACERT=$PWD\vault-ca.crt
> ```

Expose the vault endpoint

```
kubectl port-forward service/vault 8200 &
```

Set the vault endpoint as an environment variable

```
export VAULT_ADDR=https://127.0.0.1:8200 # Linux/OSX
$Env.VAULT_ADDR="https://127.0.0.1:8200" // Windows - Powershell
```

Write secrets to vault

```
vault kv put /path/to/your/secret key=value
```

### Reading Secrets from Vault

Secrets can be injected into Kubernetes Deployments at runtime by adding annotations
and setting environment variables in the manifest file.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-secrets
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-secrets
  template:
    metadata:
      labels:
        app: hello-secrets
      annotations:
        vault.security.banzaicloud.io/vault-addr: "https://vault:8200"
        vault.security.banzaicloud.io/vault-tls-secret: "vault-tls"
    spec:
      serviceAccountName: default
      containers:
      - name: alpine
        image: alpine
        command: ["sh", "-c", "echo $AWS_SECRET_ACCESS_KEY && echo going to sleep... && sleep 10000"]
        env:
        - name: AWS_SECRET_ACCESS_KEY
          value: "vault:secret/data/accounts/aws#AWS_SECRET_ACCESS_KEY"
```

On your local machine, the `vault` command can be used

```
vault kv get /path/to/your/secret
```

## Service Mesh

A service mesh is an infrastructure layer for making service-to-service communication
secure, fast, and reliable. Service meshes provide runtime debugging and observability.

This cluster was set up using [Linkerd](https://linkerd.io/2/overview/).
Follow the [linkerd install instructions](https://linkerd.io/2/getting-started/#step-1-install-the-cli).

Install the linkerd mesh with the following command.

```
linkerd install | kubectl apply -f -
```

### Setting up distributed tracing

1. Install the collector
```
kubectl apply -f https://run.linkerd.io/tracing/collector.yml
```
2. Install [Jaeger](https://www.jaegertracing.io/)
```
kubectl apply -f https://run.linkerd.io/tracing/backend.yml
```

## TODO
- ☑ Set up Vault for storing secrets
- ☑ Set up Linkerd for service mesh operations
- ☐ Set up cert-manager for managing certificates
- ☐ Set up Keycloak for SSO

# References
- Kubernetes ConfigMap Syntax [https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- Kubernetes Secret Syntax [https://kubernetes.io/docs/concepts/configuration/secret/](https://kubernetes.io/docs/concepts/configuration/secret/)
- Kubernetes Deployment Syntax [https://kubernetes.io/docs/concepts/workloads/controllers/deployment/](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- Kubernetes Service Syntax [https://kubernetes.io/docs/concepts/services-networking/service/](https://kubernetes.io/docs/concepts/services-networking/service/)
- Kubernetes Ingress Syntax [https://kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- Minikube [https://minikube.sigs.k8s.io/docs/](https://minikube.sigs.k8s.io/docs/)
- MetalLb [https://metallb.universe.tf](https://metallb.universe.tf)
- ingress-nginx [https://kubernetes.github.io/ingress-nginx/](https://kubernetes.github.io/ingress-nginx/)
- Linkerd docs [https://linkerd.io/2/](https://linkerd.io/2/)
- Cert-Manager docs [https://cert-manager.io/docs/](https://cert-manager.io/docs/)
- Consul Reference [https://www.consul.io/docs/platform/k8s/](https://www.consul.io/docs/platform/k8s/)
- Vault Reference [https://learn.hashicorp.com/vault?track=getting-started-k8s#getting-started-k8s](https://learn.hashicorp.com/vault?track=getting-started-k8s#getting-started-k8s)
- Injecting Vault Secrets Via Sidecar [https://learn.hashicorp.com/vault/getting-started-k8s/sidecar](https://learn.hashicorp.com/vault/getting-started-k8s/sidecar)
- Vault Agent Sidecar Injector Docs [https://www.vaultproject.io/docs/platform/k8s/injector](https://www.vaultproject.io/docs/platform/k8s/injector)
- Inject Secrets Into Pods [https://banzaicloud.com/blog/inject-secrets-into-pods-vault-revisited/](https://banzaicloud.com/blog/inject-secrets-into-pods-vault-revisited/)
- Vault Webhook with Consul Template [https://banzaicloud.com/blog/vault-webhook-consul-template/](https://banzaicloud.com/blog/vault-webhook-consul-template/)
- Backing up Vault with [Velero](https://velero.io/) [https://banzaicloud.com/docs/bank-vaults/backup/](https://banzaicloud.com/docs/bank-vaults/backup/)
- Keycloak Docker page [https://registry.hub.docker.com/r/jboss/keycloak](https://registry.hub.docker.com/r/jboss/keycloak)
- Gatekeeper Configuration guide [https://www.keycloak.org/docs/latest/securing_apps/#_keycloak_generic_adapter](https://www.keycloak.org/docs/latest/securing_apps/#_keycloak_generic_adapter)
- ProxyInjector [https://github.com/stakater/ProxyInjector](https://github.com/stakater/ProxyInjector)
- ProxyInject SSO with Keycloak in Kubernetes [https://medium.com/stakater/proxy-injector-enabling-sso-with-keycloak-on-kubernetes-a1012c3d9f8d](https://medium.com/stakater/proxy-injector-enabling-sso-with-keycloak-on-kubernetes-a1012c3d9f8d)