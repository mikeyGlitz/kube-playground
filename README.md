# Kubernetes Cluster for Local Development

This repository contains setup and installation for a local
kubernetes cluster using minikube.

**Table of Contents**
- [Prerequistes](#prerequisites)A
  - [Minikube on Windows](#minikube-on-windows)
- [Setting up load balancer](#setting-up-load-balancer)
- [Setting up ingress](#setting-up-ingress)
- [Storing secrets](#storing-secrets)
  - [Consul](#consul)
  - [Vault](#vault)
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

### Minikube on Windows

If you're using hyperv in Windows to manage minikube,
a script has been provided [minikube-control.ps1](./minikube-contro.ps1)
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

## Storing Secrets

### Consul
Consul is a service mesh which launches with a key-value store.
Vault will use Consul to store secrets.
Helm is the most recommended way to deploy Consul onto Kubernetes.
Before Consul can be deployed with Helm, a file, `helm-consul-values.yml` will
have to be set up in order to pass deployment configuration to Helm.

```yaml
global:
  datacenter: vault-kubernetes-guide

client:
  enabled: true

server:
  replicas: 1
  bootstrapExpect: 1
  disruptionBudget:
    maxUnavailable: 0
```

Full configuration options for the Consul Helm chart can be found at:
[https://www.consul.io/docs/platform/k8s/helm.html](https://www.consul.io/docs/platform/k8s/helm.html)

Consul can be deployed using Helm
```
helm install consul \
    --values helm-consul-values.yml \
    https://github.com/hashicorp/consul-helm/archive/v0.18.0.tar.gz
```

### Vault

Helm is the most recommended way to deploy Vault onto Kubernetes.
Before Vault can be deployed with Helm, a file, `helm-vault-values.yml` will
have to be set up in order to pass deployment configuration to Helm.

```yaml
server:
  affinity: ""
  ha:
    enabled: true
```

Full configuration options for the Vault Helm chart can be found at:
[https://www.vaultproject.io/docs/platform/k8s/helm/configuration](https://www.vaultproject.io/docs/platform/k8s/helm/configuration)

Vault can be deployed using Helm
```
helm install vault \
    --values helm-vault-values.yml \
    https://github.com/hashicorp/vault-helm/archive/v0.4.0.tar.gz
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
[//]: # "&#9744; - unchecked   &#9745; - checked"
- &#9744;&nbsp;Set up Vault for storing secrets
- &#9745;&nbsp;Set up Linkerd for service mesh operations
- &#9744;&nbsp;Set up cert-manager for managing certificates
- &#9744;&nbsp;Set up Keycloak for SSO

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
- Injecting Vault Secrets Via Sidecar [https://www.hashicorp.com/blog/injecting-vault-secrets-into-kubernetes-pods-via-a-sidecar/](https://www.hashicorp.com/blog/injecting-vault-secrets-into-kubernetes-pods-via-a-sidecar/)
- Keycloak Docker page [https://registry.hub.docker.com/r/jboss/keycloak](https://registry.hub.docker.com/r/jboss/keycloak)
- Gatekeeper Configuration guide [https://www.keycloak.org/docs/latest/securing_apps/#_keycloak_generic_adapter](https://www.keycloak.org/docs/latest/securing_apps/#_keycloak_generic_adapter)
- ProxyInjector [https://github.com/stakater/ProxyInjector](https://github.com/stakater/ProxyInjector)
- ProxyInject SSO with Keycloak in Kubernetes [https://medium.com/stakater/proxy-injector-enabling-sso-with-keycloak-on-kubernetes-a1012c3d9f8d](https://medium.com/stakater/proxy-injector-enabling-sso-with-keycloak-on-kubernetes-a1012c3d9f8d)