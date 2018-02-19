class kubernetes::cni::calico_common (
    String $cni_calico_ipip_mode         = $kubernetes::cni_calico_ipip_mode,
    Boolean $cni_calico_nat_outgoing     = $kubernetes::cni_calico_nat_outgoing,
    String $cni_cluster_cidr             = $kubernetes::cni_cluster_cidr,
  ) {

  include wget

  File {
    owner => 'root',
    group => 'root',
    mode  => "0640",
  }

  file { '/etc/cni/net.d/calico-kubeconfig':
    ensure  => file,
    content => epp("kubernetes/cni/calico/calico-kubeconfig.epp"),
    replace => false,
  }

  file { '/etc/cni/net.d/10-calico.conflist':
    ensure  => file,
    content => epp("kubernetes/cni/calico/10-calico.conflist.epp"),
    replace => false,
  }

  file { '/etc/calico':
    ensure  => directory,
  }

  file { '/etc/calico/calicoctl.cfg':
    ensure  => file,
    content => epp("kubernetes/cni/calico/calicoctl.cfg.epp"),
  }

  wget::fetch { "install calicoctl":
    source             => 'https://github.com/projectcalico/calicoctl/releases/download/v1.6.3/calicoctl',
    destination        => '/usr/local/bin/calicoctl',
    timeout            => 60,
    verbose            => false,
    nocheckcertificate => false,
    mode               => "0775",
    notify             => Exec['chmod calicoctl'],
  }

  exec { "chmod calicoctl":
    command     => '/bin/chmod 755 /usr/local/bin/calicoctl',
    refreshonly => true,
  }

}
