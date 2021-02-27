# Kubernetes Ingress support in Self-Hosted Gateway

This sample and walkthrough show how to enable Kubernetes Ingress in an Azure API Management self-hosted gateway. See [Kubernetes Ingress support in Self-Hosted Gateway]() for background and other samples. This support is currently experimental.

To enable Ingress support, the following environment variables are set up using a [deployment template](ingress-deployment.yml#L29-L34):

- `k8s.ingress.enabled` 
- Ingress object should include the annotation `kubernetes.io/ingress.class: "azure-api-management/gateway"`
- `k8s.ingress.namespace` - optional namespace where ingress is read from

## Walkthrough
In this example, we set up a namespace `gw` to contain all resources. The self-hosted gateway configuration includes [RBAC configuration]() that specifies this namespace, so it is used consistently.

One of the deployments is the [mendhak/http-https-echo:17](https://github.com/mendhak/docker-http-https-echo) container, which echoes back all HTTP/HTTPS traffic. See the latest container image tags on [Docker Hub](https://hub.docker.com/r/mendhak/http-https-echo/tags?page=1&ordering=last_updated).

### Deploy backend API service 
Let's start by creating the namespace and deploying the backend and service defined in [backend-echo.yml](backend-echo.yml).

```
kubectl create namespace gw
kubectl apply -f backend-echo.yml -n=gw
```

### Deploy API Management self-hosted gateway
Next, let's deploy the self-hosted gateway from [ingress-deployment.yml](ingress-deployment.yml).

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

Note the line below. If you are using Azure Kubernetes Service, it might take a few minutes until you see the `EXTERNAL-IP` address filled.
```
NAME                           TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                      AGE
service/apim-ingress-service   LoadBalancer   10.0.234.184   40.125.75.211   80:31394/TCP,443:31170/TCP   4m33s
service/echo-service           ClusterIP      10.0.26.176    <none>          8080/TCP                     4m20s
```
`apim-ingress-service` is exposed publicly and thus has an external IP address, while `echo-service` isn't accessible outside the cluster directly.

### Deploy Ingress rules
Now let's expose `echo-service` application via Ingress rules.
```
> kubectl apply -f ingress.yml -n=gw
ingress.networking.k8s.io/ingress created
```

### Test HTTP calls
Now that we have everything configured, let's make an HTTP call. Using an external IP address `40.125.75.211` in the preceding example:
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

## Configure SSL and hostname
To confgure hostname we need to do following steps:
1. Configure TLS certificate 
1. Configure hostname in the Ingress
1. Setup DNS server to the external IP address

### 1. Generate TLS certificate
The following commands will generate a TSL certificate and upload it as a secret to the Kubernetes cluster, where the self-hosted gateway can access it. For the purpose we can use [OpenSSL](https://github.com/openssl/openssl#download)

```
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout www.contoso.com.key -out www.contoso.com.cer -subj "/CN=www.contoso.com/O=www.contoso.com"

kubectl create secret tls tls-www-contoso-com --key www.contoso.com.key --cert www.contoso.com.cer -n=gw
``` 

### 2. Configure hostname in the Ingress object
There is a separate file [ingress-tls](ingress-tls.yml) which has the full configuration, but the main changes are in the section [section](ingress-tls.yml#L9-L12). Let's apply new rules.

```
kubectl apply -f .\ingress-tls.yml -n=gw
ingress.networking.k8s.io/ingress configured
```

### 3. Configure DNS server
Let's map `www.contoso.com` to `40.125.75.211`:
- For Windows, this can be done in [host file](https://gist.github.com/zenorocha/18b10a14b2deb214dc4ce43a2d2e2992) 
- For Linux use  [/etc/hosts](https://linuxize.com/post/how-to-edit-your-hosts-file) 

Now test the call again. Note the `--insecure` flag because the certificate is self-signed and will not be trusted. This call uses the `echo-tls` path:
```
> curl --insecure https://www.contoso.com/echo-tls/hello/ingress    
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

Optionally continue to [Kubernetes Ingress with API Management cloud configuration](../Ingress%2BCloud).