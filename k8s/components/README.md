# Kubernetes Component Library

This directory contains reusable Kustomize components that can be shared across different applications.

## Structure

```
components/
├── networking/
│   └── gke-network-policy/     # Standard GKE network policies
├── security/
│   ├── workload-identity/       # Workload Identity setup
│   └── pod-security/            # Pod Security Standards
├── observability/
│   ├── autoscaling/             # HPA + PDB
│   └── monitoring/              # Prometheus/Grafana setup
└── database/
    ├── alloydb-omni/            # AlloyDB Omni for preview
    └── cloud-sql-proxy/         # Cloud SQL proxy sidecar
```

## Usage

### Using Components in Kustomization

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yml
- service.yml

components:
- ../../components/networking/gke-network-policy
- ../../components/security/workload-identity
```

### Using Remote Components

You can also reference components from a central repository:

```yaml
components:
# From a specific tag/release
- github.com/u2i/k8s-components/networking/gke-network-policy?ref=v1.0.0
# From main branch
- github.com/u2i/k8s-components/security/workload-identity
```

## Creating a New Component

1. Create a directory under the appropriate category
2. Add a `kustomization.yml` with `kind: Component`
3. Add your resources
4. Document required parameters

Example component structure:
```
components/category/my-component/
├── kustomization.yml
├── resource1.yml
├── resource2.yml
└── README.md
```

## Benefits

- **Reusability**: Share common patterns across apps
- **Consistency**: Ensure all apps follow best practices
- **Versioning**: Components can be versioned separately
- **Modularity**: Pick and choose what you need
- **Testing**: Components can be tested independently

## Parameters

Components use standard Kustomize parameter substitution:
- `${APP_NAME}` - Application name
- `${NAMESPACE}` - Target namespace
- `${PROJECT_ID}` - GCP project ID
- `${STAGE}` - Environment stage (dev/qa/prod)
- `${BOUNDARY}` - Security boundary (nonprod/prod)

These are replaced during deployment by Cloud Deploy's `deployParameters`.