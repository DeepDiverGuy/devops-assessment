## Zero-downtime rolling update and rollback (kind)

Strategy: `RollingUpdate`, `maxUnavailable: 0`, `maxSurge: 1`. A new pod must pass its readiness probe (`/health`) before an old pod is terminated.
An availability probe hit `/health` through the Ingress every 0.2s for the whole demo.

### 1. Update 1.0.0 -> 1.1.0
$ kubectl -n devops-app set image deployment/devops-app app=devops-app:1.1.0
$ kubectl -n devops-app annotate deployment/devops-app kubernetes.io/change-cause="upgrade to 1.1.0" --overwrite
$ kubectl -n devops-app rollout status deployment/devops-app
...
Waiting for deployment “devops-app” rollout to finish: 4 out of 5 new replicas have been updated...
Waiting for deployment “devops-app” rollout to finish: 1 old replicas are pending termination...
deployment “devops-app” successfully rolled out
$ curl -s localhost:8081/
{“message”:”Hello from DevOps Task!”,”status”:”running”,”version”:”1.1.0"}
$ kubectl -n devops-app rollout history deployment/devops-app
REVISION CHANGE-CAUSE
1 <none>
2 upgrade to 1.1.0
(The HPA had scaled the Deployment to 5 replicas during the earlier load test, so the update replaced 5 pods.)

### 2. Rollback
$ kubectl -n devops-app rollout undo deployment/devops-app
deployment.apps/devops-app rolled back
$ kubectl -n devops-app rollout status deployment/devops-app
deployment “devops-app” successfully rolled out
$ curl -s localhost:8081/
{“message”:”Hello from DevOps Task!”,”status”:”running”,”version”:”1.0.0"}
$ kubectl -n devops-app rollout history deployment/devops-app
REVISION CHANGE-CAUSE
2 upgrade to 1.1.0
3 <none>

### 3. Availability during update and rollback
total requests: 562
non-200: 0
