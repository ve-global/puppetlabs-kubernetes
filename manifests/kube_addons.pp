# Class kuberntes kube_addons
class kubernetes::kube_addons (

  Boolean $bootstrap_controller                   = $kubernetes::bootstrap_controller,
  Optional[String]$cni_network_provider           = $kubernetes::cni_network_provider,
  Boolean $install_dashboard                      = $kubernetes::install_dashboard,
  String $kubernetes_version                      = $kubernetes::kubernetes_version,
  Boolean $controller                             = $kubernetes::controller,
  Boolean $taint_master                           = $kubernetes::taint_master,
  Optional[String] $cni_provider                  = $kubernetes::cni_provider,
  Boolean $install_ingress_controller             = $kubernetes::install_ingress_controller,
  Optional[String] $ingress_controller_provider   = $kubernetes::ingress_controller_provider,
){

  Exec {
    path        => ['/usr/bin', '/bin'],
    environment => [ 'HOME=/root', 'KUBECONFIG=/root/admin.conf'],
    logoutput   => true,
    tries       => 5,
    try_sleep   => 5,
  }

  if $bootstrap_controller {

    # include the code for the cni provider
    case $cni_provider {
      'calico': {
        include kubernetes::cni::calico_bootstrap_controller
        contain kubernetes::cni::calico_bootstrap_controller
      }
      default:  {
        include kubernetes::cni::default
        contain kubernetes::cni::default
      }
    }

    if $install_ingress_controller == true {
      case $ingress_controller_provider {
        'calico': {
          include kubernetes::ingress::traefik 
          contain kubernetes::ingress::traefik
        }
      }
    }

    $addon_dir = '/etc/kubernetes/addons'

    exec { 'Create kube proxy service account':
      command     => 'kubectl create -f kube-proxy-sa.yaml',
      cwd         => $addon_dir,
      subscribe   => File['/etc/kubernetes/addons/kube-proxy-sa.yaml'],
      refreshonly => true,
      # require     => Exec['Install cni network provider'],
    }

    exec { 'Create kube proxy ConfigMap':
      command     => 'kubectl create -f kube-proxy.yaml',
      cwd         => $addon_dir,
      subscribe   => File['/etc/kubernetes/addons/kube-proxy.yaml'],
      refreshonly => true,
      # require     => Exec['Create kube proxy service account'],
    } ~>

    exec { 'Create kube proxy daemonset':
      command     => 'kubectl create -f kube-proxy-daemonset.yaml',
      cwd         => $addon_dir,
      subscribe   => File['/etc/kubernetes/addons/kube-proxy-daemonset.yaml'],
      refreshonly => true,
      # require     => Exec['Create kube proxy ConfigMap'],
    } ~>

    exec { 'Create kube dns service account':
      command     => 'kubectl create -f kube-dns-sa.yaml',
      cwd         => $addon_dir,
      subscribe   => File['/etc/kubernetes/addons/kube-dns-sa.yaml'],
      refreshonly => true,
    } ~>

    exec { 'Create kube dns service':
      command     => 'kubectl create -f kube-dns-service.yaml',
      cwd         => $addon_dir,
      subscribe   => File['/etc/kubernetes/addons/kube-dns-service.yaml'],
      refreshonly => true,
      require     => Exec['Create kube dns service account'],
    } ~>

    exec { 'Create kube dns deployment':
      command     => 'kubectl create -f kube-dns-deployment.yaml',
      cwd         => $addon_dir,
      subscribe   => File['/etc/kubernetes/addons/kube-dns-deployment.yaml'],
      refreshonly => true,
      # require     => Exec['Create kube dns service account'],
    }
  }

  if $controller {
    exec { 'Assign master role to controller':
      command => "kubectl label node ${::hostname} node-role.kubernetes.io/master=",
      path    => "/bin:/usr/bin",
      unless  => "kubectl describe nodes ${::hostname} | tr -s ' ' | grep 'Roles: master'",
    }

    if $taint_master {

      exec { 'Checking for dns to be deployed':
        path      => ['/usr/bin', '/bin'],
        command   => 'kubectl get deploy -n kube-system kube-dns -o yaml | tr -s " " | grep "Deployment has minimum availability"',
        tries     => 50,
        try_sleep => 10,
        logoutput => true,
        onlyif    => 'kubectl get deploy -n kube-system kube-dns -o yaml | tr -s " " | grep "Deployment does not have minimum availability"', # lint:ignore:140chars
        }

      exec { 'Taint master node':
        command => "kubectl taint nodes ${::hostname} key=value:NoSchedule",
        onlyif  => 'kubectl get nodes',
        unless  => "kubectl describe nodes ${::hostname} | tr -s ' ' | grep 'Taints: key=value:NoSchedule'"
      }
    }
  }


  if $install_dashboard and $kubernetes_version =~ /1[.](8|9)[.]\d/ {
    exec { 'Install Kubernetes dashboard':
      command => 'kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml',
      onlyif  => 'kubectl get nodes',
      unless  => 'kubectl -n kube-system get pods | grep kubernetes-dashboard',
      }
    }
  if $install_dashboard and $kubernetes_version =~ /1[.](6|7)[.]\d/ {
    exec { 'Install Kubernetes dashboard':
      command => 'kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.6.3/src/deploy/kubernetes-dashboard.yaml',
      onlyif  => 'kubectl get nodes',
      unless  => 'kubectl -n kube-system get pods | grep kubernetes-dashboard',
      }
    }

}
