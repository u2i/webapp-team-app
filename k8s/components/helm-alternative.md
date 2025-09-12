# Alternative: Helm Charts for Resource Libraries

If you prefer Helm over Kustomize components, you can create a chart library:

## Structure
```
charts/
├── gke-base-app/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── network-policy.yaml
│       ├── service-account.yaml
│       ├── hpa.yaml
│       └── pdb.yaml
└── alloydb-omni/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        └── dbcluster.yaml
```

## Usage in Skaffold
```yaml
deploy:
  helm:
    releases:
    - name: webapp
      chartPath: charts/gke-base-app
      valuesFiles:
      - values/dev.yaml
      setValueTemplates:
        app.name: "{{.APP_NAME}}"
        app.namespace: "{{.NAMESPACE}}"
```

## Pros/Cons vs Kustomize Components

**Helm Pros:**
- More powerful templating (loops, conditionals)
- Package management (helm repo)
- Built-in rollback

**Kustomize Components Pros:**
- Native to Kubernetes
- No templating language to learn
- Better GitOps integration
- Works directly with Cloud Deploy