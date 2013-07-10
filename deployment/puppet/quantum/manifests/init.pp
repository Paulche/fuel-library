#
class quantum (
  $rabbit_password,
  $auth_password,
  $enabled                = true,
  $package_ensure         = 'present',
  $verbose                = 'False',
  $debug                  = 'False',
  $bind_host              = '0.0.0.0',
  $bind_port              = '9696',
  $core_plugin            = 'quantum.plugins.openvswitch.ovs_quantum_plugin.OVSQuantumPluginV2',
  $auth_strategy          = 'keystone',
  $base_mac               = 'fa:16:3e:00:00:00',
  $mac_generation_retries = 16,
  $dhcp_lease_duration    = 120,
  $allow_bulk             = 'True',
  $allow_overlapping_ips  = 'False',
  $rpc_backend            = 'quantum.openstack.common.rpc.impl_kombu',
  $control_exchange       = 'quantum',
  $rabbit_host            = 'localhost',
  $rabbit_port            = '5672',
  $rabbit_user            = 'guest',
  $rabbit_virtual_host    = '/',
  $rabbit_ha_virtual_ip   = false,
  $server_ha_mode         = false,
  $auth_type        = 'keystone',
  $auth_host        = 'localhost',
  $auth_port        = '35357',
  $auth_tenant      = 'services',
  $auth_user        = 'quantum',
  $use_syslog = false
) {
  include 'quantum::params'

  anchor {'quantum-init':}

  if ! defined(File['/etc/quantum']) {
    file {'/etc/quantum':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => 755,
      #require => Package['quantum']
    }
  }

  package {'quantum':
    name   => $::quantum::params::package_name,
    ensure => $package_ensure
  }

  if is_array($rabbit_host) and size($rabbit_host) > 1 {
    if $rabbit_ha_virtual_ip {
      $rabbit_hosts = "${rabbit_ha_virtual_ip}:${rabbit_port}"
    } else {
      $rabbit_hosts = inline_template("<%= @rabbit_host.map {|x| x + ':' + @rabbit_port}.join ',' %>")
    }
    Quantum_config['DEFAULT/rabbit_ha_queues'] -> Service<| title == 'quantum-server' |>
    Quantum_config['DEFAULT/rabbit_ha_queues'] -> Service<| title == 'quantum-ovs-agent' |>
    Quantum_config['DEFAULT/rabbit_ha_queues'] -> Service<| title == 'quantum-l3' |>
    Quantum_config['DEFAULT/rabbit_ha_queues'] -> Service<| title == 'quantum-dhcp-agent' |>
    quantum_config {
      'DEFAULT/rabbit_ha_queues': value => 'True';
      'DEFAULT/rabbit_hosts':     value => $rabbit_hosts;
    }
  } else {
    quantum_config {
      'DEFAULT/rabbit_host': value => is_array($rabbit_host) ? { false => $rabbit_host, true => join($rabbit_host) };
      'DEFAULT/rabbit_port': value => $rabbit_port;
    }
  }

  if $server_ha_mode {
    $real_bind_host = $bind_host
  } else {
    $real_bind_host = '0.0.0.0'
  }

  quantum_config {
    'DEFAULT/verbose':                value => $verbose;
    'DEFAULT/debug':                  value => $debug;
    'DEFAULT/bind_host':              value => $real_bind_host;
    'DEFAULT/bind_port':              value => $bind_port;
    'DEFAULT/auth_strategy':          value => $auth_strategy;
    'DEFAULT/core_plugin':            value => $core_plugin;
    'DEFAULT/base_mac':               value => $base_mac;
    'DEFAULT/mac_generation_retries': value => $mac_generation_retries;
    'DEFAULT/dhcp_lease_duration':    value => $dhcp_lease_duration;
    'DEFAULT/allow_bulk':             value => $allow_bulk;
    'DEFAULT/allow_overlapping_ips':  value => $allow_overlapping_ips;
    'DEFAULT/rpc_backend':            value => $rpc_backend;
    'DEFAULT/control_exchange':       value => $control_exchange;
    'DEFAULT/rabbit_userid':          value => $rabbit_user;
    'DEFAULT/rabbit_password':        value => $rabbit_password;
    'DEFAULT/rabbit_virtual_host':    value => $rabbit_virtual_host;
    'keystone_authtoken/auth_host':         value => $auth_host;
    'keystone_authtoken/auth_port':         value => $auth_port;
    'keystone_authtoken/admin_tenant_name': value => $auth_tenant;
    'keystone_authtoken/admin_user':        value => $auth_user;
    'keystone_authtoken/admin_password':    value => $auth_password;
  }
  if $use_syslog {
    file { "quantum-logging.conf":
      content => template('quantum/logging.conf-syslog.erb'),
      path  => "/etc/quantum/logging.conf",
      owner => "root",
      group => "root",
      mode  => 644,
    }
  } else {
    file { "quantum-logging.conf":
      content => template('quantum/logging.conf.erb'),
      path  => "/etc/quantum/logging.conf",
      owner => "root",
      group => "root",
      mode  => 644,
    }
  }
  quantum_config {'DEFAULT/log_config': value => "/etc/quantum/logging.conf";}
  File['/etc/quantum'] -> File['quantum-logging.conf']

  if defined(Anchor['quantum-server-config-done']) {
    $endpoint_quantum_main_configuration = 'quantum-server-config-done'
  } else {
    $endpoint_quantum_main_configuration = 'quantum-init-done'
  }

  Anchor['quantum-init'] -> 
    Package['quantum'] -> 
      Quantum_config<||> -> 
        Quantum_api_config<||> ->
          Anchor[$endpoint_quantum_main_configuration]

  anchor {'quantum-init-done':}
}
