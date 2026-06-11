helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install --replace falco --namespace falco --create-namespace --set tty=true falcosecurity/falco

kubectl get pods -n falco

helm upgrade --namespace falco falco falcosecurity/falco --set falcosidekick.enabled=true --set falcosidekick.webui.enabled=true
