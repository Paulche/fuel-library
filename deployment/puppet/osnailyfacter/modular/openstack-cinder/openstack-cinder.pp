notice('MODULAR: openstack-cinder.pp')

#Network stuff
prepare_network_config(hiera('network_scheme', {}))
$cinder_hash            = hiera_hash('cinder_hash', {})
$management_vip         = hiera('management_vip')
$queue_provider         = hiera('queue_provider', 'rabbitmq')
$cinder_volume_group    = hiera('cinder_volume_group', 'cinder')
$nodes_hash             = hiera('nodes', {})
$storage_hash           = hiera_hash('storage', {})
$ceilometer_hash        = hiera_hash('ceilometer_hash',{})
$rabbit_hash            = hiera_hash('rabbit_hash', {})
$service_endpoint       = hiera('service_endpoint')
$service_workers        = pick($cinder_hash['workers'], min(max($::processorcount, 2), 16))
$cinder_db_password     = $cinder_hash[db_password]
$cinder_user_password   = $cinder_hash[user_password]
$keystone_user          = pick($cinder_hash['user'], 'cinder')
$keystone_tenant        = pick($cinder_hash['tenant'], 'services')
$region                 = hiera('region', 'RegionOne')
$db_host                = pick($cinder_hash['db_host'], hiera('database_vip'))
$cinder_db_user         = pick($cinder_hash['db_user'], 'cinder')
$cinder_db_name         = pick($cinder_hash['db_name'], 'cinder')
$roles                  = node_roles($nodes_hash, hiera('uid'))
$ssl_hash               = hiera_hash('use_ssl', {})

$keystone_auth_protocol = get_ssl_property($ssl_hash, {}, 'keystone', 'internal', 'protocol', 'http')
$keystone_auth_host     = get_ssl_property($ssl_hash, {}, 'keystone', 'internal', 'hostname', [hiera('keystone_endpoint', ''), $service_endpoint, $management_vip])

$glance_protocol        = get_ssl_property($ssl_hash, {}, 'glance', 'internal', 'protocol', 'http')
$glance_endpoint        = get_ssl_property($ssl_hash, {}, 'heat', 'internal', 'hostname', [hiera('glance_endpoint', ''), $management_vip])
$glance_ssl_usage       = get_ssl_property($ssl_hash, {}, 'glance', 'internal', 'usage', false)
if $glance_ssl_usage {
  $glance_api_servers = "${glance_protocol}://${glance_endpoint}:9292"
} else {
  $glance_api_servers    = hiera('glance_api_servers', "${management_vip}:9292")
}

$service_port = '5000'
$auth_uri     = "${keystone_auth_protocol}://${keystone_auth_host}:${service_port}/"
$identity_uri = "${keystone_auth_protocol}://${keystone_auth_host}:${service_port}/"

# Determine who should get the volume service
if (member($roles, 'cinder') and $storage_hash['volumes_lvm']) {
  $manage_volumes = 'iscsi'
} elsif ($storage_hash['volumes_ceph']) {
  $manage_volumes = 'ceph'
} else {
  $manage_volumes = false
}

# SQLAlchemy backend configuration
$max_pool_size = min($::processorcount * 5 + 0, 30 + 0)
$max_overflow = min($::processorcount * 5 + 0, 60 + 0)
$max_retries = '-1'
$idle_timeout = '3600'

$openstack_version = {
  'keystone'   => 'installed',
  'glance'     => 'installed',
  'horizon'    => 'installed',
  'nova'       => 'installed',
  'novncproxy' => 'installed',
  'cinder'     => 'installed',
}

######### Cinder Controller Services ########
class {'openstack::cinder':
  sql_connection       => "mysql://${cinder_db_user}:${cinder_db_password}@${db_host}/${cinder_db_name}?charset=utf8&read_timeout=60",
  queue_provider       => $queue_provider,
  amqp_hosts           => hiera('amqp_hosts',''),
  amqp_user            => $rabbit_hash['user'],
  amqp_password        => $rabbit_hash['password'],
  rabbit_ha_queues     => true,
  volume_group         => $cinder_volume_group,
  physical_volume      => undef,
  manage_volumes       => $manage_volumes,
  enabled              => true,
  glance_api_servers   => $glance_api_servers,
  bind_host            => get_network_role_property('cinder/api', 'ipaddr'),
  iscsi_bind_host      => get_network_role_property('cinder/iscsi', 'ipaddr'),
  keystone_user        => $keystone_user,
  keystone_tenant      => $keystone_tenant,
  auth_uri             => $auth_uri,
  region               => $region,
  identity_uri         => $identity_uri,
  cinder_user_password => $cinder_user_password,
  use_syslog           => hiera('use_syslog', true),
  use_stderr           => hiera('use_stderr', false),
  verbose              => pick($cinder_hash['verbose'], hiera('verbose', true)),
  debug                => pick($cinder_hash['debug'], hiera('debug', true)),
  default_log_levels   => hiera_hash('default_log_levels'),
  syslog_log_facility  => hiera('syslog_log_facility_cinder', 'LOG_LOCAL3'),
  cinder_rate_limits   => hiera('cinder_rate_limits'),
  max_retries          => $max_retries,
  max_pool_size        => $max_pool_size,
  max_overflow         => $max_overflow,
  idle_timeout         => $idle_timeout,
  ceilometer           => $ceilometer_hash[enabled],
  service_workers      => $service_workers,
} # end class

####### Disable upstart startup on install #######
if($::operatingsystem == 'Ubuntu') {
  tweaks::ubuntu_service_override { 'cinder-api':
    package_name => 'cinder-api',
  }
  tweaks::ubuntu_service_override { 'cinder-backup':
    package_name => 'cinder-backup',
  }
  tweaks::ubuntu_service_override { 'cinder-scheduler':
    package_name => 'cinder-scheduler',
  }
}
