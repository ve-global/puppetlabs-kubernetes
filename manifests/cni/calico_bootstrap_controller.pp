class kubernetes::cni::calico_bootstrap_controller (
    String $cni_calico_ipip_mode         = $kubernetes::cni_calico_ipip_mode,
    Boolean $cni_calico_nat_outgoing     = $kubernetes::cni_calico_nat_outgoing,
    String $cni_cluster_cidr             = $kubernetes::cni_cluster_cidr,
    String $etcd_initial_cluster         = $kubernetes::etcd_initial_cluster,

  ) {

  File {
    owner  => 'root',
    group  => 'root'
  }

  $cni_etcd_endpoints = $etcd_initial_cluster.regsubst(":[0-9]+", ":6667", 'G').regsubst('^etcd-', 'calico-etcd', 'G')

  file { '/var/lib/calico/rbac.yaml':
    ensure  => file,
    content => epp("kubernetes/cni/calico/rbac.yaml.epp"),
  }

  file { '/var/lib/calico/calico.yaml':
    ensure  => file,
    content => epp("kubernetes/cni/calico/calico.yaml.epp"),
  }

  # wait until the apiserver is up
  exec { 'wait-for-apiserver':
    path      => ['/usr/bin', '/bin'],
    command   => "kubectl get nodes | grep ${facts['networking']['hostname']}",
    tries     => 50,
    try_sleep => 10,
    logoutput => true,
  }

  # install the rbac configuration
  exec { 'Install rbac definition for cni network provider':
    path        => ['/usr/bin', '/bin'],
    command     => "kubectl apply -f /var/lib/calico/rbac.yaml",
    onlyif      => 'kubectl get nodes',
    refreshonly => true,
    subscribe   => File['/var/lib/calico/rbac.yaml'],
    require     => Exec['wait-for-apiserver'],
  }

  # install the cni provider
  exec { 'Install cni network provider':
    path        => ['/usr/bin', '/bin'],
    command     => "kubectl apply -f /var/lib/calico/calico.yaml",
    onlyif      => 'kubectl get nodes',
    refreshonly => true,
    subscribe   => File['/var/lib/calico/calico.yaml'],
    require     => Exec['wait-for-apiserver'],
  }

  # configure the ip pool
  file { '/var/lib/calico/ippool.yaml':
    ensure  => file,
    content => epp("kubernetes/cni/calico/ippool.yaml.epp"),
  }

  exec { 'Configure the calico ip pool':
    path        => ['/usr/bin', '/bin'],
    command     => '/bin/cat /var/lib/calico/ippool.yaml | /usr/local/bin/calicoctl apply -f -',
    subscribe   => File['/var/lib/calico/ippool.yaml'],
    refreshonly => true,
    logoutput   => true,
    require     => [
      Exec['wait-for-apiserver'],
      Exec['chmod calicoctl'],
    ],
  }
}
