# Azure API Management Self-Hosted Gateway Ingress samples

## What is Azure API Management Self-Hosted Gateway?

[Self-hosted gateway](https://aka.ms/apim/sputnik/overview) is a feature of [Azure API Management](https://aka.ms/apimrocks). The self-hosted gateway, a containerized version of the API Management gateway component, expands API Management support for hybrid and multi-cloud environments. It allows customers to manage all of their APIs using a single API management solution without compromising security, compliance, or performance. Customers can deploy the self-hosted gateways to the same environments where they host their APIs while continuing to manage them from an associated API Management service in Azure.

[More samples on self-hosted gateway repository](https://github.com/Azure/api-management-self-hosted-gateway)

## Kubernetes Ingress support in Self-Hosted Gateway

[Kubernetes Ingress](https://v1-18.docs.kubernetes.io/docs/concepts/services-networking/ingress/) resource is an API object that manages external access to the services in a cluster, typically HTTP.
With this experimental support in Azure API Management Gateway following features can be configured Ingress object networking.k8s.io/v1beta1:
- SSL termination
- API route exposure
- Supports both [Exact and Prefix](https://v1-18.docs.kubernetes.io/docs/concepts/services-networking/ingress/#path-types) path types

To enable ingress support, the following environment variables need to be set up ([link to template](../../tree/main/Ingress-only/ingress-deployment.yml#L29-L34)):

- `k8s.ingress.enabled` 
- Ingress object should include the annotation `kubernetes.io/ingress.class: "azure-api-management/gateway"`
- `k8s.ingress.namespace` - optional namespace where ingress is read from

[Kubernetes Ingress only samples and walkthrough](../../tree/main/Ingress-only)

## Hybrid support with a cloud configuration
Normally self-hosted gateway would have the environment variables needed to communicate to Azure API Management service which deployed to the cloud to retrieve the configuration:
- `config.service.endpoint` 
- `config.service.auth`

Here is the [snippet](https://github.com/Azure/api-management-self-hosted-gateway/blob/master/examples/self-hosted-gateway-with-configuration-backup.yaml#L39-L47) of the configuration and [article on the Azure documentation site](https://docs.microsoft.com/en-us/azure/api-management/how-to-deploy-self-hosted-gateway-kubernetes)

Combining all those environment variables would give the power of configuring basic routes via Kubernetes Ingress routes and the full power of Azure API Management policies and transformations via cloud configuration.

### How is configuration applied
Upon starting a new instance of the self-hosted gateway container, it looks for ingress in the namespace passed as an environment variable `k8s.ingress.namespace` and creates routes, certificates, hostnames, and gateway entities. 
Next, looking at `config.service.*` settings, the gateway is connecting to the cloud service to fetch cloud configuration snapshot and starts listening on configuration changes.
From that point the gateway is initialized and confguration changes from Ingress and Cloud configuration are applied in **last one wins** strategy. 
Periodically, the gateway is creating a snapshot of the most recent effective confguration from the cloud to be able to load faster on next boot. Kubernetes Ingress objects are not added to the snapshot as those are cluster specific and on next gateway boot might be different.

**Important**: Snapshot and configuration change events from dual source can create discrepancy on the active configuration in case of conflict. For example consifer following order:
1. Self-hosted gateway boots on the K8 clusters in hybrid configuration mode.
1. Cloud configuration is adding `/users` API. 
1. Ingress is adding a new `/users` route this overwriting the cloud API.
1. All runtime calls will be executed as per Ingress confguration

Now if the pod is torn down or nodes reboot, configuration will be loaded as:
1. Loading ingress object which has `/users` route
1. Cloud confguration snapshot will overwrite `/users` route from snapshot. 
