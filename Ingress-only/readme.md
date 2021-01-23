# Kubernetes Ingress support in Self-Hosted Gateway

[Kubernetes Ingress](https://v1-18.docs.kubernetes.io/docs/concepts/services-networking/ingress/) resource is an API object that manages external access to the services in a cluster, typically HTTP.
With this experimental support in Azure API Management Gateway following features can be configured Ingress object networking.k8s.io/v1beta1:
- SSL termination
- API route exposure
- Supports both [Exact and Prefix](https://v1-18.docs.kubernetes.io/docs/concepts/services-networking/ingress/#path-types) path types

To enable ingress support, following environment variables need to be setup ([link to template](.\ingress-only\ingress-controller-deployment.yml#L29-L34)):
- `k8s.ingress.enabled` 
- Ingress object should include the annotation `kubernetes.io/ingress.class: "azure-api-management/gateway"`
- `k8s.ingress.namespace` - optional namespace where ingress is read from

## Walkthrough
In this example we will setup a namespace `gw` which will contain all resources. Self-hosted gateway file contains [RBAC configuration]() that specifies this namespace so it is better to stick to it
One of the deployments is a container that echoes back all HTTP/HTTPS traffic [mendhak/http-https-echo:17](https://github.com/mendhak/docker-http-https-echo). Also see latest tags on [DockerHub](https://hub.docker.com/r/mendhak/http-https-echo/tags?page=1&ordering=last_updated)

### Deploying backend API service 
Let's start by creating the namespace and deploying the backend and service defined in [backend-echo.yml](backend-echo.yml):

```
kubectl create namespace gw
kubectl apply -f backend-echo.yml -n=gw
```

### Deploying API Managment self-hosted gateway
Next let's deploy self-hosted gateway from [ingress-deployment.yml](ingress-deployment.yml)
```
kubectl apply -f ingress-deployment.yml -n=gw
```

At that point your namespace should looks like this:
 ```
 > kubectl get all -n=gw
NAME                                               READY   STATUS    RESTARTS   AGE
pod/apim-ingress-pod-6655496c5f-kctjz   1/1     Running   0          49s
pod/httpecho-deployment-594f697f6-69t4l            1/1     Running   0          49s

NAME                                      TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
service/apim-ingress-service   LoadBalancer   10.99.197.181   <pending>     80:32603/TCP,443:30444/TCP      49s
service/echo-service                      LoadBalancer   10.108.169.48   <pending>     8443:31955/TCP,8480:30535/TCP   49s

NAME                                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/apim-ingress-pod   1/1     1            1           49s
deployment.apps/httpecho-deployment           1/1     1            1           49s

NAME                                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/apim-ingress-pod-6655496c5f   1         1         1       49s
replicaset.apps/httpecho-deployment-594f697f6            1         1         1       49s

 ```
