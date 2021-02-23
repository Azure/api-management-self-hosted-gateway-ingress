kubectl apply -f .\ingress.yml -n=gw
kubectl apply -f .\backend-echo.yml -n=gw
kubectl apply -f .\ingress-deployment.yml -n=gw
kubectl get all -n=gw