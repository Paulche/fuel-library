notice('MODULAR: sahara.pp')

prepare_network_config(hiera('network_scheme', {}))

$access_admin               = hiera_hash('access_hash', {})
$sahara_hash                = hiera_hash('sahara_hash', {})
$rabbit_hash                = hiera_hash('rabbit_hash', {})
$public_ssl_hash            = hiera('public_ssl')
$ceilometer_hash            = hiera_hash('ceilometer_hash', {})
$primary_controller         = hiera('primary_controller')
$public_vip                 = hiera('public_vip')
$database_vip               = hiera('database_vip', undef)
$management_vip             = hiera('management_vip')
$neutron_config             = hiera_hash('neutron_config')
$use_neutron                = hiera('use_neutron', false)
$service_endpoint           = hiera('service_endpoint')
$syslog_log_facility_sahara = hiera('syslog_log_facility_sahara')
$debug                      = pick($sahara_hash['debug'], hiera('debug', false))
$verbose                    = pick($sahara_hash['verbose'], hiera('verbose', true))
$default_log_levels         = hiera_hash('default_log_levels')
$use_syslog                 = hiera('use_syslog', true)
$use_stderr                 = hiera('use_stderr', false)
$rabbit_ha_queues           = hiera('rabbit_ha_queues')
$amqp_port                  = hiera('amqp_port')
$amqp_hosts                 = hiera('amqp_hosts')

#################################################################

if $sahara_hash['enabled'] {
  $firewall_rule   = '201 sahara-api'
  $api_bind_port   = '8386'
  $api_bind_host   = get_network_role_property('sahara/api', 'ipaddr')
  $public_address = $public_ssl_hash['services'] ? {
    true    => $public_ssl_hash['hostname'],
    default => $public_vip,
  }
  $public_protocol = $public_ssl_hash['services'] ? {
    true    => 'https',
    default => 'http',
  }
  $sahara_user     = pick($sahara_hash['user'], 'sahara')
  $sahara_password = pick($sahara_hash['user_password'])
  $tenant          = pick($sahara_hash['tenant'], 'services')
  $db_user         = pick($sahara_hash['db_user'], 'sahara')
  $db_name         = pick($sahara_hash['db_name'], 'sahara')
  $db_password     = pick($sahara_hash['db_password'])
  $db_host         = pick($sahara_hash['db_host'], $database_vip)
  $max_pool_size   = min($::processorcount * 5 + 0, 30 + 0)
  $max_overflow    = min($::processorcount * 5 + 0, 60 + 0)
  $max_retries     = '-1'
  $idle_timeout    = '3600'
  $read_timeout    = '60'
  $sql_connection  = "mysql://${db_user}:${db_password}@${db_host}/${db_name}?read_timeout=${read_timeout}"

  ####### Disable upstart startup on install #######
  tweaks::ubuntu_service_override { 'sahara-api':
    package_name => 'sahara',
  }

  firewall { $firewall_rule :
    dport   => $api_bind_port,
    proto   => 'tcp',
    action  => 'accept',
  }

  class { 'sahara' :
    host                   => $api_bind_host,
    port                   => $api_bind_port,
    verbose                => $verbose,
    debug                  => $debug,
    use_syslog             => $use_syslog,
    use_stderr             => $use_stderr,
    plugins                => [ 'ambari', 'cdh', 'mapr', 'spark', 'vanilla' ],
    log_facility           => $syslog_log_facility_sahara,
    database_connection    => $sql_connection,
    database_max_pool_size => $max_pool_size,
    database_max_overflow  => $max_overflow,
    database_max_retries   => $max_retries,
    database_idle_timeout  => $idle_timeout,
    auth_uri               => "http://${service_endpoint}:5000/v2.0/",
    identity_uri           => "http://${service_endpoint}:35357/",
    rpc_backend            => 'rabbit',
    use_neutron            => $use_neutron,
    admin_user             => $sahara_user,
    admin_password         => $sahara_password,
    admin_tenant_name      => $tenant,
    rabbit_userid          => $rabbit_hash['user'],
    rabbit_password        => $rabbit_hash['password'],
    rabbit_ha_queues       => $rabbit_ha_queues,
    rabbit_port            => $amqp_port,
    rabbit_hosts           => split($amqp_hosts, ',')
  }

  if $public_ssl_hash['services'] {
    file { '/etc/pki/tls/certs':
      mode => 755,
    }

    file { '/etc/pki/tls/certs/public_haproxy.pem':
      mode => 644,
    }

    sahara_config {
      'object_store_access/public_identity_ca_file':     value => '/etc/pki/tls/certs/public_haproxy.pem';
      'object_store_access/public_object_store_ca_file': value => '/etc/pki/tls/certs/public_haproxy.pem';
    }
  }

  class { 'sahara::service::api': }

  class { 'sahara::service::engine': }

  class { 'sahara::client': }

  if $ceilometer_hash['enabled'] {
    class { '::sahara::notify':
      enable_notifications => true,
    }
  }

  $haproxy_stats_url = "http://${management_vip}:10000/;csv"

  haproxy_backend_status { 'sahara' :
    name => 'sahara',
    url  => $haproxy_stats_url,
  }

  if $primary_controller {
    haproxy_backend_status { 'keystone-public' :
      name  => 'keystone-1',
      url   => $haproxy_stats_url,
    }

    haproxy_backend_status { 'keystone-admin' :
      name  => 'keystone-2',
      url   => $haproxy_stats_url,
    }

    class { 'sahara_templates::create_templates' :
      use_neutron   => $use_neutron,
      auth_user     => $access_admin['user'],
      auth_password => $access_admin['password'],
      auth_tenant   => $access_admin['tenant'],
      auth_uri      => "${public_protocol}://${public_address}:5000/v2.0/",
      internal_net  => try_get_value($neutron_config, 'default_private_net', 'admin_internal_net'),
    }

    Haproxy_backend_status['keystone-admin'] -> Haproxy_backend_status['sahara']
    Haproxy_backend_status['keystone-public'] -> Haproxy_backend_status['sahara']
    Haproxy_backend_status['sahara'] -> Class['sahara_templates::create_templates']
  }

  Firewall[$firewall_rule] -> Class['sahara::service::api']
  Service['sahara-api'] -> Haproxy_backend_status['sahara']
}
#########################

class openstack::firewall {}
include openstack::firewall
