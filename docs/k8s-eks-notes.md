## Moving this setup to production on EKS

| Area | kind (this repo) | EKS in production |
|---|---|---|
| Ingress | ingress-nginx with a host port mapping | AWS Load Balancer Controller (ALB Ingress) or ingress-nginx behind an NLB, with TLS from ACM or cert-manager, plus Route 53 DNS |
| Secrets | `kubectl create secret`, not committed | AWS Secrets Manager or SSM Parameter Store, synced with External Secrets Operator or the Secrets Store CSI driver; envelope encryption of etcd secrets with a KMS key |
| AWS access | none | IAM Roles for Service Accounts (IRSA) or EKS Pod Identity, one least-privilege role per workload, no static keys |
| Node scaling | 2 fixed workers | Karpenter or Cluster Autoscaler so HPA scale-out has nodes to land on; multiple AZs; managed node groups or Bottlerocket nodes |
| Images | `kind load` of a local image | Pull from ECR or GHCR by immutable tag or digest with pull credentials; signature verification (Cosign) in an admission policy |
| Metrics | metrics-server with `--kubelet-insecure-tls` | metrics-server without the insecure flag (valid kubelet certs); kube-prometheus-stack for monitoring |
| Availability | single control plane | managed control plane, PodDisruptionBudget, topology spread constraints across AZs |
| Security | non-root, read-only root FS, dropped capabilities | the same, plus the Pod Security Standard "restricted" enforced per namespace, NetworkPolicies, private cluster endpoint |
| Releases | `kubectl set image` and `rollout undo` | GitOps (Argo CD or Flux) or CI-driven Helm/Kustomize deploys; progressive delivery (Argo Rollouts) for canaries |
