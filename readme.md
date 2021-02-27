# Azure API Management Self-Hosted Gateway Ingress samples

The samples in this repository show how to set up an Azure API Management self-hosted gateway to provide Kubernetes Ingress support. Kubernetes Ingress support in the self-hosted gateway is currently experimental.

* [Kubernetes Ingress only](../../tree/main/Ingress-only)
* [Kubernetes Ingress with API Management cloud configuration](../../tree/main/Ingress%2BCloud)

## What is Azure API Management self-hosted gateway?

[Self-hosted gateway](https://aka.ms/apim/sputnik/overview) is a feature of [Azure API Management](https://aka.ms/apimrocks). The self-hosted gateway, a containerized version of the API Management gateway component, expands API Management support for hybrid and multi-cloud environments. It allows customers to manage all of their APIs using a single API management solution without compromising security, compliance, or performance. Customers can deploy the self-hosted gateways to the same environments where they host their APIs while continuing to manage them from an associated API Management service in Azure.

See [Azure API Management self-hosted gateway samples](https://github.com/Azure/api-management-self-hosted-gateway)

## Kubernetes Ingress support in self-hosted gateway

[Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) resource is an API object that manages external access to the services in a cluster, typically over HTTP.

With this experimental support in the Azure API Management Gateway, the following features can be configured in the Ingress object using the networking.k8s.io/v1beta1 API:
- SSL termination
- API route exposure
- Support for both [exact and prefix](https://v1-18.docs.kubernetes.io/docs/concepts/services-networking/ingress/#path-types) path types

To enable Ingress support, the following environment variables need to be set up (see [deployment template](../../tree/main/Ingress-only/ingress-deployment.yml#L29-L34)):

- `k8s.ingress.enabled` 
- Ingress object should include the annotation `kubernetes.io/ingress.class: "azure-api-management/gateway"`
- `k8s.ingress.namespace` - optional namespace where Ingress is read from

See [deployment sample and walkthrough](../../tree/main/Ingress-only).

## Hybrid support with a cloud configuration
Normally, the self-hosted gateway would have the following environment variables which are needed to communicate with the Azure API Management service deployed to the cloud:
- `config.service.endpoint` 
- `config.service.auth`

Here is a [snippet](https://github.com/Azure/api-management-self-hosted-gateway/blob/master/examples/self-hosted-gateway-with-configuration-backup.yaml#L39-L47) of the configuration. For details, see  [Deploy a self-hosted gateway to Kubernetes](https://docs.microsoft.com/azure/api-management/how-to-deploy-self-hosted-gateway-kubernetes).

Combining these environment variables with the environment variables for Ingress configures basic routes via Kubernetes Ingress and the full power of Azure API Management policies and transformations via cloud configuration.

See [deployment sample and walkthrough](../../tree/main/Ingress%2BCloud).

### How is configuration applied?

Upon starting a new instance of the self-hosted gateway container, it looks for Ingress in the namespace passed as an environment variable `k8s.ingress.namespace` and creates routes, certificates, hostnames, and gateway entities. 

Next, looking at `config.service.*` settings, the gateway connects to the cloud service to fetch a cloud configuration snapshot and starts listening for configuration changes.

From that point, the gateway is initialized and configuration changes from Ingress and cloud configuration are applied in a **last one wins** strategy. 

Periodically, the gateway creates a snapshot of the most recent effective confguration from the cloud to be able to load faster on next boot. Kubernetes Ingress objects are not added to the snapshot, because those are cluster specific and might differ on the next gateway boot.

**Important**: Conflicting snapshot and configuration change events from two sources can cause discrepancies in the active configuration. For example, consider the following order:
1. Self-hosted gateway boots on a Kubernetes cluster in hybrid configuration mode.
1. Cloud configuration adds a `/users` API. 
1. Ingress adds a new `/users` route, overwriting the cloud API.
1. All runtime calls will be executed as per Ingress confguration

Now if the pod is torn down or nodes reboot, configuration will be loaded as:
1. Load the Ingress object, which has `/users` route
1. Cloud confguration will overwrite `/users` route from snapshot. 
