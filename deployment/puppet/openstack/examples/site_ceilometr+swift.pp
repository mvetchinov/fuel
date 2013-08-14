$deployment_id = '48'
Exec { logoutput => true, path => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'] }
stage {'openstack-custom-repo': before => Stage['main']}
$mirror_type="default"
class { 'openstack::mirantis_repos': stage => 'openstack-custom-repo', type=>$mirror_type }
$swift_vip = '192.168.122.220'
#$public_virtual_ip   = '10.0.204.253'
$internal_virtual_ip = '192.168.122.211'
$ceilometr_vip = '192.168.122.211'
$public_interface = 'eth0'
$mongo_slave_ip = '192.168.122.210'
$mongo_arbiter_ip = '192.168.122.212'
#   ['192.168.122.209', '192.168.122.210']
$nodes_harr = [
  {
    'name' => 'swiftproxy-01',
    'role' => 'primary-swift-proxy',
    'role2' => 'haproxy',
    'internal_address' => '192.168.122.212',
    'public_address'   => '192.168.122.212',
    'haproxy_proxy'  =>  true,
    'ha_serv' => 'swift-proxy',
    'mongo_arbiter' => true,
    'p_keep' => 'master',
  },
  {
    'name' => 'swiftproxy-02',
    'role' => 'swift-proxy',
    'internal_address' => '192.168.123.205',
    'public_address'   => '192.168.123.205',
    'ha_serv' => 'swift-proxy',
    'p_keep' => 'slave',
  },
  {
    'name' => 'swiftproxy-04',
    'role' => 'swift-proxy',
    'internal_address' => '192.168.122.209',
    'public_address'   => '192.168.122.209',
    'ha_serv' => 'swift-proxy',
    'p_keep' => 'slave2',
  },
 {
    'name' => 'ceilometr-01',
    'role' => 'ceilometr',
    'role2' => 'haproxy',
    'ha_serv' => 'ceilometr',
    'internal_address' => '192.168.122.209',
    'public_address'   => '192.168.122.209',
    'internal_interface' => 'eth0',
    'primary_controller' => true,
    'haproxy_ceilometr' => true,
    'master_ceilometr' => true,
    'mongo_master' => true,
    'public_interface' => 'eth0',
    'r_keep' => 'master',
  },
 {
    'name' => 'ceilometr-02',
    'role' => 'ceilometr',
    'role2' => 'haproxy',
    'ha_serv' => 'ceilometr',
    'internal_address' => '192.168.122.210',
    'public_address'   => '192.168.122.210',
    'slave_controller' => 'true',
    'haproxy_ceilometr' => true,
    'r_keep' => 'slave',
  },
  {
    'name' => 'swift-01',
    'role' => 'storage',
    'internal_address' => '192.168.122.212',
    'public_address'   => '192.168.122.212',
    'swift_zone'       => 1,
    'mountpoints'=> "1 2\n 2 1",
    'storage_local_net_ip' => '192.168.122.212',
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
$nodeha = filter_nodes($nodes,'role2',$::hostname)
$node = filter_nodes($nodes,'name',$::hostname)
if empty($node) {
  fail("Node $::hostname is not defined in the hash structure")
}
$internal_address = $node[0]['internal_address']
$public_address = $node[0]['public_address']
$swift_local_net_ip      = $internal_address
#if $node[0]['role'] == 'primary-swift-proxy' {
#  $primary_proxy = true
#} else {
#  $primary_proxy = false
#}
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
node keystone inherits haproxy  {
  # set up mysql server
#  class { 'mysql::server':
#    config_hash => {
#      # the priv grant fails on precise if I set a root password
#      # TODO I should make sure that this works
#      # 'root_password' => $mysql_root_password,
#      'bind_address'  => '0.0.0.0'
#    }
# }
  # set up all openstack databases, users, grants
#  class { 'keystone::db::mysql':
#    password => $keystone_db_password,
#}
  # install and configure the keystone service
  class { 'keystone':
    admin_token  => $keystone_admin_token,
    # we are binding keystone on all interfaces
    # the end user may want to be more restrictive
    bind_host    => $internal_address,
    verbose  => $verbose,
    debug    => $verbose,
    catalog_type => 'sql',
  }
  # set up keystone database
  # set up the keystone config for mysql
  class { 'openstack::db::mysql':
    keystone_db_password => $keystone_db_password,
    nova_db_password => $keystone_db_password,
    mysql_root_password => $keystone_db_password,
    cinder_db_password => $keystone_db_password,
    glance_db_password => $keystone_db_password,
    quantum_db_password => $keystone_db_password,
    mysql_bind_address => $internal_address,
  }
  # set up keystone admin users
  class { 'keystone::roles::admin':
    email    => $admin_email,
    password => $admin_password,
  }
  # configure the keystone service user and endpoint
  class { 'swift::keystone::auth':
    password => $swift_user_password,
    address  => $swift_vip,
  }
}
# The following specifies 3 swift storage nodes
#      'ha_serv' => 'ceilometr'
#$ha_servv = $ha_serv
$hav_serv = $node[0]['ha_serv']
case $hav_serv {
 "ceilometr": {
$ceilometr_nodes = merge_arrays(filter_nodes($nodes,'role','ceilometr'),filter_nodes($nodes,'role','ceilometr'))
$ceilometr_ha = nodes_to_hash($ceilometr_nodes,'name','internal_address')
  Haproxy_service {
      balancers => $ceilometr_ha
    }
}
 "swift-proxy": {
#$swift_proxy_nodes = merge_arrays(filter_nodes($nodes,'role','primary-swift-proxy'),filter_nodes($nodes,'role','swift-proxy'))
#$swift_proxies = nodes_to_hash($swift_proxy_nodes,'name','internal_address')
    Haproxy_service {
      balancers => $swift_proxies
    }
}
 }
#$haproxy_roles = filter_nodes($nodes,'ha_serv','ceilometr')
#$balancers = $haproxy_roles[0]['public_address']
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
      $balancer_port = 5673
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
node 'haproxy'  {
notify { "Applying $name class": }
sysctl::value { 'net.ipv4.ip_nonlocal_bind': value => '1' }
include  haproxy::params
    file { '/etc/rsyslog.d/haproxy.conf':
      ensure => present,
      content => 'local0.* -/var/log/haproxy.log'
    }
    class { 'haproxy':
      enable => true,
      global_options   => merge($::haproxy::params::global_options, {'log' => "/dev/log local0"}),
      defaults_options => merge($::haproxy::params::defaults_options, {'mode' => 'http'}),
      require => Sysctl::Value['net.ipv4.ip_nonlocal_bind'],
    }
 }
    $public_vrid   = $::deployment_id
    $internal_vrid = $::deployment_id + 1
$mongo_arbiter = $node[0]['mongo_arbiter']
$mongo_master = $node[0]['mongo_master']
$r_keep = $node[0]['r_keep']
$p_keep = $node[0]['p_keep']
case $r_keep {
  "master": {
   keepalived::instance { $internal_vrid:
      interface => 'eth0',
      virtual_ips => [$internal_virtual_ip],
      state    =>   'MASTER',
      priority =>  101,
       } 
 
          }
 "slave": {
    keepalived::instance { $internal_vrid:
      interface => 'eth0',
      virtual_ips => [$internal_virtual_ip],
      state    =>   'SLAVE',
      priority =>  100,
    }    
 }
 "default": {}
}
$master_ceilometr = $node[0]['master_ceilometr']
node /ceilometr-[\d+]/ inherits haproxy {
 include stdlib
  class { 'operatingsystem::checksupported':
      stage => 'setup'
  }
$ceilometr_nodes = filter_nodes($nodes,'role','ceilometr')
$ceilometr_ha = nodes_to_hash($ceilometr_nodes,'name','internal_address')
haproxy_service { 'rabbitmq-epmd':    order => 91, port => 5672, ssl => "", virtual_ips => [$internal_virtual_ip], define_backend => true }
 notify { "Applying $name class": }
        class {'::mongodb':}
        mongodb::mongod {
            "mongod_instance":
                mongod_instance => "mongodb1",
                mongod_port => '27018',
                mongod_replSet => "MongoCluster01",
                mongod_add_options => ['slowms = 50']
        }
   ::logrotate::rule { 'mongodb': path => '/var/log/mongo/*.log', rotate => 5, rotate_every => 'day', compress => true,}
notify {" I am  $master_ceilometr":}
if $mongo_master {
  exec {"initiate":
        command => "mongo --port 27018 admin --eval \"printjson(rs.initiate({\\\"_id\\\": \\\"mongoCluster1\\\", \\\"members\\\":[{_id: 0,host:\\\"$mongo_slave_ip:27018\\\"}]}))\" >> /root/mongo",
        path    => ["/usr/bin","/bin"],
        require => Class["::mongodb"],
                                           }
  exec {"wait":
        command => "sleep 30",
        path    => ["/usr/bin","/bin"],
        require => Exec["initiate"],
                                         }
  exec {"initiate2":
        command => "mongo --port 27018 admin --eval \"printjson(rs.initiate({\\\"_id\\\": \\\"mongoCluster1\\\", \\\"members\\\":[{_id: 0,host:\\\"$mongo_arbiter_ip:27018,true\\\"}]}))\" >> /root/mongo",
        path    => ["/usr/bin","/bin"],
        require => Class["::mongodb"],
                                           }
  exec {"wait2":
        command => "sleep 30",
        path    => ["/usr/bin","/bin"],
        require => Exec["initiate"],
                                         }
                  }   # fi master_ceilometr
#}
#  node_ip_address => '192.168.122.209', #getvar("::ipaddress_${::internal_interface}"),
$rabbit_password         = 'nova'
$rabbit_user             = 'nova'
$version = '2.8.7-2.el6'
$env_config =''
class { 'rabbitmq':
  config_cluster         => true,
  config_mirrored_queues => true,
  cluster_nodes          => ['192.168.122.209', '192.168.122.210'],
  wipe_db_on_cookie_change => true,
  default_user           => $rabbit_user,
  default_pass           => $rabbit_password,
  port                   => '5673'
}
 if $master_ceilometr {   
 
 exec { 'delete-public-virtual-ip':
  command => "ip a d ${ceilometr_vip} dev ${public_interface} label",
        unless  => "ip addr show dev ${public_interface} | grep -w ${ceilometr_vip}",
        path    => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'],
      }
->
 exec { 'create-public-virtual-ip':
  command => "ip addr add ${ceilometr_vip} dev ${public_interface} label",
        unless  => "ip addr show dev ${public_interface} | grep -w ${ceilometr_vip}",
        path    => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'],
      }
}
class {keepalived:}
    
}
node /swiftproxy-[\d+]/ inherits keystone {
    haproxy_service { 'keystone-1': order => 20, port => 35357, ssl => "", virtual_ips => [$swift_vip]  }
    haproxy_service { 'keystone-2': order => 30, port => 5000, ssl => "", virtual_ips => [$swift_vip]  }
    haproxy_service { 'mysqld': order => 95, port => 3306, ssl => "", virtual_ips => [$swift_vip], define_backend => true }
    haproxy_service { 'swift': order => 96, port => 8080, ssl => "ssl crt /etc/haproxy/cert.pem\n  reqadd X-Forwarded-Proto:\ https", virtual_ips => [$swift_vip], balancers => $swift_proxies }
file { 'cert.pem':
        path    => '/etc/haproxy/cert.pem',
        ensure  => file,
        require => Package['haproxy'],
        content => template("haproxy/cert.pem.erb"),
      }
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
if $mongo_arbiter    {  
       class {'::mongodb':}
        mongodb::mongod {
            "mongod_instance":
                mongod_instance => "mongodb1",
                mongod_port => '27018',
                mongod_replSet => "MongoCluster01",
                mongod_add_options => ['slowms = 50']
        }
   ::logrotate::rule { 'mongodb': path => '/var/log/mongo/*.log', rotate => 5, rotate_every => 'day', compress => true,}
}
 if $master_ceilometr {
 exec { 'delete-public-virtual-ip':
  command => "ip a d ${ceilometr_vip} dev ${public_interface} label",
        unless  => "ip addr show dev ${public_interface} | grep -w ${ceilometr_vip}",
        path    => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'],
      }
->
 exec { 'create-public-virtual-ip':
  command => "ip addr add ${ceilometr_vip} dev ${public_interface} label",
        unless  => "ip addr show dev ${public_interface} | grep -w ${ceilometr_vip}",
        path    => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'],
      }
}
case $p_keep {
  "master": {
   keepalived::instance { $internal_vrid:
      interface => 'eth0',
      virtual_ips => [$swift_vip],
      state    =>   'MASTER',
      priority =>  101,
       }
          }
 "slave": {
    keepalived::instance { $internal_vrid:
      interface => 'eth0',
      virtual_ips => [$swift_vip],
      state    =>   'SLAVE',
      priority =>  100,
    }
 }
 "slave2": {
    keepalived::instance { $internal_vrid:
      interface => 'eth0',
      virtual_ips => [$swift_vip],
      state    =>   'SLAVE',
      priority =>  101,
    }
 }
 "default": {}
}
class {keepalived:}
}
