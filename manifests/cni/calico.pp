class kubernetes::cni::calico (
    String $cni_calico_ipip_mode         = $kubernetes::cni_calico_ipip_mode,
    Boolean $cni_calico_nat_outgoing     = $kubernetes::cni_calico_nat_outgoing,
    String $cni_cluster_cidr             = $kubernetes::cni_cluster_cidr,
  ) {

  File {
    owner  => 'root',
    group  => 'root'
  }

  include wget

  # # install calicoctl
  # file { '/usr/local/bin/calicoctl':
  #   source => 'https://github.com/projectcalico/calicoctl/releases/download/v1.6.3/calicoctl',
  #   mode   => '0755',
  # }

  wget::fetch { "download the jdk7 file":
    source             => 'https://github.com/projectcalico/calicoctl/releases/download/v1.6.3/calicoctl',
    destination        => '/usr/local/bin/calicoctl',
    timeout            => 60,
    verbose            => true,
    nocheckcertificate => false,
  }

  # deploy the manifest for the provider
  file { '/var/lib/calico':
    ensure => directory,
  }

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
    command     => "kubectl apply -f /var/lib/calico/rbac.yaml",
    onlyif      => 'kubectl get nodes',
    refreshonly => true,
    subscribe   => File['/var/lib/calico/rbac.yaml'],
    require     => Exec['wait-for-apiserver'],
  }

  # install the cni provider
  exec { 'Install cni network provider':
    command => "kubectl apply -f /var/lib/calico/calico.yaml",
    onlyif  => 'kubectl get nodes',
    refreshonly => true,
    subscribe => File['/var/lib/calico/calico.yaml'],
    require     => Exec['wait-for-apiserver'],
  }

  # configure the ip pool
  file { '/var/lib/calico/ippool.yaml':
    ensure  => file,
    content => epp("kubernetes/cni/calico/ippool.yaml.epp"),
  }

  exec { 'Configure the calico ip pool':
    command     => 'cat /var/lib/calico/ippool.yaml | calicoctl apply -f -',
    subscribe   => File['/var/lib/calico/ippool.yaml'],
    refreshonly => true,
    logoutput   => true,
    require     => Exec['wait-for-apiserver'],
  }
}
