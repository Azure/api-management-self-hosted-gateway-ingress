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

To enable ingress support, following environment variables need to be setup ([link to template](../../tree/main/Ingress-only/ingress-deployment.yml#L29-L34)):

- `k8s.ingress.enabled` 
- Ingress object should include the annotation `kubernetes.io/ingress.class: "azure-api-management/gateway"`
- `k8s.ingress.namespace` - optional namespace where ingress is read from

[Kubernetes Ingress only samples and walkthrough](../../tree/main/Ingress-only)

## Hybrid support with cloud configuration
Normally self-hosted gateway would have the environment variables needed to communicate to Azure API Management service which deployed to the cloud to retrieve the configuration:
- `config.service.endpoint` 
- `config.service.auth`

Here is the [snippet](https://github.com/Azure/api-management-self-hosted-gateway/blob/master/examples/self-hosted-gateway-with-configuration-backup.yaml#L39-L47) of the configuration and [dcoumentation on Azure docs site](https://docs.microsoft.com/en-us/azure/api-management/how-to-deploy-self-hosted-gateway-kubernetes)

Combining all those environment variables would give the power of configuring basic routes via Kubernetes Ingress routes and the full power of Azure API Management policies and transformations via cloud configuration.

### How is configuration applied
Upon starting new instance of the self-hosted gateway container