# Kubernetes Ingress support in Self-Hosted Gateway

[Kubernetes Ingress](https://v1-18.docs.kubernetes.io/docs/concepts/services-networking/ingress/) resource is an API object that manages external access to the services in a cluster, typically HTTP.
With this experimental support in Azure API Management Gateway following features can be configured Ingress object networking.k8s.io/v1beta1:
- SSL termination
- API route exposure
- Supports both [Exact and Prefix](https://v1-18.docs.kubernetes.io/docs/concepts/services-networking/ingress/#path-types) path types

To enable ingress support, the following environment variables need to be set up ([link to template](ingress-deployment.yml#L29-L34)):

- `k8s.ingress.enabled` 
- Ingress object should include the annotation `kubernetes.io/ingress.class: "azure-api-management/gateway"`
- `k8s.ingress.namespace` - optional namespace where ingress is read from

## Walkthrough
In this example, we will set up a namespace `gw` which will contain all resources. Self-hosted gateway file contains [RBAC configuration]() that specifies this namespace so it is better to stick to it
One of the deployments is a container that echoes back all HTTP/HTTPS traffic [mendhak/http-https-echo:17](https://github.com/mendhak/docker-http-https-echo). Also, see the latest tags on [DockerHub](https://hub.docker.com/r/mendhak/http-https-echo/tags?page=1&ordering=last_updated)

### Deploying backend API service 
Let's start by creating the namespace and deploying the backend and service defined in [backend-echo.yml](backend-echo.yml):

```
kubectl create namespace gw
kubectl apply -f backend-echo.yml -n=gw
```

### Deploying API Management self-hosted gateway
Next, let's deploy the self-hosted gateway from [ingress-deployment.yml](ingress-deployment.yml)
```
kubectl apply -f ingress-deployment.yml -n=gw
```

At that point your namespace should look like this:
 ```
> kubectl get all -n=gw
NAME                                       READY   STATUS    RESTARTS   AGE
pod/apim-ingress-pod-69864d749b-s6nnm      1/1     Running   0          40s
pod/httpecho-deployment-57c4686bdb-rwzfq   1/1     Running   0          29s

NAME                           TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
service/apim-ingress-service   LoadBalancer   10.0.11.47     <pending>     80:30879/TCP,443:32764/TCP   40s
service/echo-service           ClusterIP      10.0.142.199   <none>        8443/TCP,8480/TCP            29s

NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/apim-ingress-pod      1/1     1            1           40s
deployment.apps/httpecho-deployment   1/1     1            1           29s

NAME                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/apim-ingress-pod-69864d749b      1         1         1       40s
replicaset.apps/httpecho-deployment-57c4686bdb   1         1         1       29s
 ```

Note the line below. If you are using AKS it might take a few minutes until you get EXTERNAL-IP address filled
```
NAME                           TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                      AGE
service/apim-ingress-service   LoadBalancer   10.0.234.184   40.125.75.211   80:31394/TCP,443:31170/TCP   4m33s
service/echo-service           ClusterIP      10.0.26.176    <none>          8080/TCP                     4m20s
```
`apim-ingress-service` is exposed publicly and thus has an external IP address, while for echo-service, we don't want to have it accessible outside the cluster directly.

### Deploying ingress rules
Now let's expose `echo-service` application via Ingress rules
```
> kubectl apply -f ingress.yml -n=gw
ingress.networking.k8s.io/ingress created
```

### Testing HTTP calls
Now that we have everything configured, let's make an HTTP call. Using an external IP address `40.125.75.211` in the case above:
```
> curl http://40.125.75.211/echo/hello/ingress   
{
  "path": "/echo/hello/ingress",
  "headers": {
    "accept": "*/*",
    "user-agent": "curl/7.55.1",
    "host": "echo-service.gw.svc.cluster.local:8080",
    "x-forwarded-for": "10.240.0.5"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "echo-service.gw.svc.cluster.local",   
  "ip": "10.240.0.5",
  "ips": [
    "10.240.0.5"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [
    "svc",
    "gw",
    "echo-service"
  ],
  "xhr": false,
  "os": {
    "hostname": "httpecho-deployment-7758b7747f-c4dbk"
  },
  "connection": {}
}
```

## Configuring SSL and host name
To confgure hostname we need to do following steps:
1. Configure TLS certificate 
1. Configure host name in the ingress
1. Setup DNS server to the External IP

Let's start in order:
### 1. Generate TLS certificate
Following command will generate TSL certificate and upload it as a secret to Kubernetes cluster from where Self-hosted gateway can get it. For the purpose we can use [OpenSSL](https://github.com/openssl/openssl#download)
```
"C:\Program Files\OpenSSL-Win64\bin\openssl" req -x509 -nodes -days 365 -newkey rsa:2048 -keyout www.contoso.com.key -out www.contoso.com.cer -subj "/CN=www.contoso.com/O=www.contoso.com"
kubectl create secret tls tls-www-contoso-com --key www.contoso.com.key --cert www.contoso.com.cer -n=gw
``` 
### 2. Configure host name in the Ingress object
There is a separate file [ingress-tls](ingress-tls.yml) which has the full configuration, but the main changes are in the section [tls section](ingress-tls.yml#L9-L12). Let's apply new rules
```
kubectl apply -f .\ingress-tls.yml -n=gw
ingress.networking.k8s.io/ingress configured
```

### 3. Configure DNS server
Let's map `www.contoso.com` to `40.125.75.211`:
- For Windows, this can be done in [host file](https://gist.github.com/zenorocha/18b10a14b2deb214dc4ce43a2d2e2992) 
- For Linux use  [/etc/hosts](https://linuxize.com/post/how-to-edit-your-hosts-file) 

Now let's test the call again (Note the `--insecure` flag as the certificate is self-signed and will not be trusted):
```
> curl --insecure https://www.contoso.com/echo/hello/ingress    
{
  "path": "/echo/hello/ingress",
  "headers": {
    "accept": "*/*",
    "user-agent": "curl/7.55.1",
    "host": "echo-service.gw.svc.cluster.local:8080",
    "x-forwarded-for": "10.244.3.1"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "echo-service.gw.svc.cluster.local",
  "ip": "10.244.3.1",
  "ips": [
    "10.244.3.1"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [
    "svc",
    "gw",
    "echo-service"
  ],
  "xhr": false,
  "os": {
    "hostname": "httpecho-deployment-7758b7747f-c4dbk"
  },
  "connection": {}
}
```
 