# Kubernetes Cluster for Local Development

This repository contains setup and installation for a local
kubernetes cluster using minikube.

**Table of Contents**
- [Prerequistes](#prerequisites)
- [Setting up load balancer](#setting-up-load-balancer)
- [Setting up ingress](#setting-up-ingress)
- [Service Mesh](#service-mesh)
  - [Setting up distributed tracing](#setting-up-distributed-tracing)
- [TODO](#todo)

## Prerequisites

1. Install [minikube](https://minikube.sigs.k8s.io/docs/start/)
2. Initialize minikube cluster using VM driver
```
minikube start --driver=<hyperv|virtualbox>
```

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