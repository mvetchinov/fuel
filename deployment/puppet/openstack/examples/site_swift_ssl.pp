$deployment_id = '88'
Exec { logoutput => true, path => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'] }
stage {'openstack-custom-repo': before => Stage['main']}
$mirror_type="default"
class { 'openstack::mirantis_repos': stage => 'openstack-custom-repo', type=>$mirror_type }
$public_virtual_ip   = '10.0.204.253'
$internal_virtual_ip = '192.168.122.77'
$nodes_harr = [
  {
    'name' => 'swiftproxy-01',
    'role' => 'primary-swift-proxy',
    'internal_address' => '192.168.123.100',
    'public_address'   => '192.168.123.100',
  },
  {
    'name' => 'swiftproxy-02',
    'role' => 'swift-proxy',
    'internal_address' => '192.168.123.205',
    'public_address'   => '192.168.123.205',
  },
  {
    'name' => 'swiftproxy-04',
    'role' => 'swift-proxy',
    'internal_address' => '192.168.122.209',
    'public_address'   => '192.168.122.209',
  },
  {
    'name' => 'swift-01',
    'role' => 'storage',
    'internal_address' => '192.168.123.100',
    'public_address'   => '192.168.123.100',
    'swift_zone'       => 1,
    'mountpoints'=> "1 2\n 2 1",
    'storage_local_net_ip' => '192.168.123.100',
  },
  {
    'name' => 'swift-02',
    'role' => 'storage',
    'internal_address' => '192.168.123.101',
    'public_address'   => '192.168.123.101',
    'swift_zone'       => 2,
    'mountpoints'=> "1 2\n 2 1",
    'storage_local_net_ip' => '192.168.123.101',
  },
  {
    'name' => 'swift-03',
    'role' => 'storage',
    'internal_address' => '192.168.123.102',
    'public_address'   => '192.168.123.102',
    'swift_zone'       => 3,
    'mountpoints'=> "1 2\n 2 1",
    'storage_local_net_ip' => '192.168.123.102',
  }
]
$nodes = $nodes_harr
$internal_netmask = '255.255.255.0'
$public_netmask = '255.255.255.0'
$node = filter_nodes($nodes,'name',$::hostname)
if empty($node) {
  fail("Node $::hostname is not defined in the hash structure")
}
$internal_address = $node[0]['internal_address']
$public_address = $node[0]['public_address']
$swift_local_net_ip      = $internal_address
$master_swift_proxy_nodes = filter_nodes($nodes,'role','primary-swift-proxy')
$master_swift_proxy_ip = $master_swift_proxy_nodes[0]['internal_address']
$swift_proxy_nodes = merge_arrays(filter_nodes($nodes,'role','primary-swift-proxy'),filter_nodes($nodes,'role','swift-proxy'))
$swift_proxies = nodes_to_hash($swift_proxy_nodes,'name','internal_address')
$nv_physical_volume     = ['vdb','vdc']
$swift_loopback = false
$swift_user_password     = 'swift'
$verbose                = true
$admin_email          = 'dan@example_company.com'
$keystone_db_password = 'keystone'
$keystone_admin_token = 'keystone_token'
$admin_user           = 'admin'
$admin_password       = 'nova'
node keystone {
  class { 'keystone':
    admin_token  => $keystone_admin_token,
    bind_host    => '0.0.0.0',
    verbose  => $verbose,
    debug    => $verbose,
    catalog_type => 'sql',
  }
  class { 'openstack::db::mysql':
    keystone_db_password => $keystone_db_password,
    nova_db_password => $keystone_db_password,
    mysql_root_password => $keystone_db_password,
    cinder_db_password => $keystone_db_password,
    glance_db_password => $keystone_db_password,
    quantum_db_password => $keystone_db_password,
  }
  class { 'keystone::roles::admin':
    email    => $admin_email,
    password => $admin_password,
  }
  class { 'swift::keystone::auth':
    password => $swift_user_password,
    address  => "192.168.122.100",
  }
}
node /swift-[\d+]/ {
  include stdlib
  class { 'operatingsystem::checksupported':
      stage => 'setup'
  }
  $swift_zone = $node[0]['swift_zone']
  class { 'openstack::swift::storage_node':
    swift_zone             => $swift_zone,
    swift_local_net_ip     => $swift_local_net_ip,
    master_swift_proxy_ip  => $master_swift_proxy_ip,
    storage_devices        => $nv_physical_volume,
    storage_base_dir       => '/dev/',
    db_host                => $internal_virtual_ip,
    service_endpoint       => $internal_virtual_ip,
    cinder                 => false
  }
}
node /swiftproxy-[\d+]/ inherits keystone {
  include stdlib
  class { 'operatingsystem::checksupported':
      stage => 'setup'
  }
   $primary_proxy = true
  if $primary_proxy {
    ring_devices {'all':
      storages => filter_nodes($nodes, 'role', 'storage')
    }
  }
  class { 'openstack::swift::proxy':
    swift_user_password     => $swift_user_password,
    swift_proxies           => $swift_proxies,
    primary_proxy           => $primary_proxy,
    controller_node_address => $internal_address,
    swift_local_net_ip      => $internal_address,
    master_swift_proxy_ip   => $internal_address,
  }
file { 'cert.pem':
        path    => '/etc/haproxy/cert.pem',
        ensure  => file,
        require => Package['haproxy'],
        content => template("haproxy/cert.pem.erb"),
      }
    include haproxy::params
    Haproxy_service {
      balancers => $swift_proxies
    }
    file { '/etc/rsyslog.d/haproxy.conf':
      ensure => present,
      content => 'local0.* -/var/log/haproxy.log'
    }
    haproxy_service { 'keystone-1': order => 20, port => 35357, ssl => "", virtual_ips => [$public_virtual_ip, $internal_virtual_ip]  }
    haproxy_service { 'keystone-2': order => 30, port => 5000, ssl => "", virtual_ips => [$public_virtual_ip, $internal_virtual_ip]  }
    haproxy_service { 'rabbitmq-epmd':    order => 91, port => 4369, ssl => "", virtual_ips => [$internal_virtual_ip], define_backend => true }
    haproxy_service { 'mysqld': order => 95, port => 3306, ssl => "", virtual_ips => [$internal_virtual_ip], define_backend => true }
    haproxy_service { 'swift': order => 96, port => 8080, ssl => "ssl crt /etc/haproxy/cert.pem\n  reqadd X-Forwarded-Proto:\ https", virtual_ips => [$public_virtual_ip,$internal_virtual_ip], balancers => $swift_proxies }
    sysctl::value { 'net.ipv4.ip_nonlocal_bind': value => '1' }
    package { 'socat': ensure => present }
    class { 'haproxy':
      enable => true,
      global_options   => merge($::haproxy::params::global_options, {'log' => "/dev/log local0"}),
      defaults_options => merge($::haproxy::params::defaults_options, {'mode' => 'http'}),
      require => Sysctl::Value['net.ipv4.ip_nonlocal_bind'],
    }
 }
define haproxy_service($order, $balancers, $virtual_ips, $port, $ssl, $define_cookies = false, $define_backend = false) {
  case $name {
    "mysqld": {
      $haproxy_config_options = { 'option' => ['mysql-check user cluster_watcher', 'tcplog','clitcpka','srvtcpka'], 'balance' => 'roundrobin', 'mode' => 'tcp', 'timeout server' => '28801s', 'timeout client' => '28801s' }
      $balancermember_options = 'check inter 15s fastinter 2s downinter 1s rise 5 fall 3'
      $balancer_port = 3307
    }
    "rabbitmq-epmd": {
      $haproxy_config_options = { 'option' => ['clitcpka'], 'balance' => 'roundrobin', 'mode' => 'tcp'}
      $balancermember_options = 'check inter 5000 rise 2 fall 3'
      $balancer_port = 4369
    }
    "swift": {
      $haproxy_config_options = { 'option' => ['httplog'], 'balance' => 'roundrobin' }
      $balancermember_options = 'check'
      $balancer_port = $port
    }
    default: {
      $haproxy_config_options = { 'option' => ['httplog'], 'balance' => 'roundrobin' }
      $balancermember_options = 'check'
      $balancer_port = $port
    }
  }
  add_haproxy_service { $name :
    order                    => $order,
    balancers                => $balancers,
    virtual_ips              => $virtual_ips,
    port                     => $port,
    ssl                      => $ssl,
    haproxy_config_options   => $haproxy_config_options,
    balancer_port            => $balancer_port,
    balancermember_options   => $balancermember_options,
    define_cookies           => $define_cookies,
    define_backend           => $define_backend,
  }
}
define add_haproxy_service (
    $order,
    $balancers,
    $virtual_ips,
    $port,
    $ssl,
    $haproxy_config_options,
    $balancer_port,
    $balancermember_options,
    $mode = 'tcp',
    $define_cookies = false,
    $define_backend = false,
    $collect_exported = false
    ) {
    haproxy::listen { $name:
      order            => $order - 1,
      ipaddress        => $virtual_ips,
      ports            => $port,
      ssl              => $ssl,
      options          => $haproxy_config_options,
      collect_exported => $collect_exported,
      mode             => $mode,
    }
    @haproxy::balancermember { "${name}":
      order                  => $order,
      listening_service      => $name,
      balancers              => $balancers,
      balancer_port          => $balancer_port,
      balancermember_options => $balancermember_options,
      define_cookies         => $define_cookies,
      define_backend        =>  $define_backend,
    }
}
