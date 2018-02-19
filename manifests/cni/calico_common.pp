class kubernetes::cni::calico_common (
    String $cni_calico_ipip_mode         = $kubernetes::cni_calico_ipip_mode,
    Boolean $cni_calico_nat_outgoing     = $kubernetes::cni_calico_nat_outgoing,
    String $cni_cluster_cidr             = $kubernetes::cni_cluster_cidr,
  ) {

  File {
    owner  => 'root',
    group  => 'root'
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

}
