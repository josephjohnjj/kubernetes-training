helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace prometheus

kubectl --namespace prometheus get pods -l "release=prometheus"

Get Grafana 'admin' user password by running:

  kubectl --namespace prometheus get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

Access Grafana local instance:

  export POD_NAME=$(kubectl --namespace prometheus get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname)
  kubectl --namespace prometheus port-forward $POD_NAME 3000

Get your grafana admin user password by running:

  kubectl get secret --namespace prometheus -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo




kubectl patch svc prometheus-grafana \
  -n prometheus \
  -p '{"spec":{"type":"NodePort"}}'



from login


sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
sudo ss -tlnp | grep 3000
curl -I http://10.0.1.65:32715/login
