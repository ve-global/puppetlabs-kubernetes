class kubernetes::ingress::traefik () {

  exec { 'Install Traefik Ingress Controller RBAC':
    command => 'kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-rbac.yaml',
    onlyif  => 'kubectl get nodes',
    unless  => 'kubectl -n kube-system get clusterrolebindings | grep traefik-ingress-controller',
  }

  exec { 'Install Traefik Ingress Controller DaemonSet':
    command => 'kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-ds.yaml',
    onlyif  => 'kubectl get nodes',
    unless  => 'kubectl -n kube-system get daemonsets | grep traefik-ingress-controller',
  }

  exec { 'Install Traefik Ingress Controller Dashboard':
    command => 'kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/ui.yaml',
    onlyif  => 'kubectl get nodes',
    unless  => 'kubectl -n kube-system get services | grep traefik-web-ui',
  }

}
