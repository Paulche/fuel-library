#
# == Class: openstack::horizon
#
# Class to install / configure horizon.
# Will eventually include apache and ssl.
#
# NOTE: Will the inclusion of memcache be an issue?
#       Such as if the server already has memcache installed?
#       -jtopjian
#
# === Parameters
#
# See params.pp
#
# === Examples
#
# class { 'openstack::horizon':
#   secret_key => 'dummy_secret_key',
# }
#

class openstack::horizon (
  $secret_key,
  $bind_address            = '127.0.0.1',
  $cache_server_ip         = '127.0.0.1',
  $cache_server_port       = '11211',
  $neutron                 = false,
  $neutron_options         = {},
  $horizon_app_links       = undef,
  $keystone_url            = 'http://127.0.0.1:5000/v2.0/',
  $keystone_default_role   = '_member_',
  $verbose                 = false,
  $debug                   = false,
  $api_result_limit        = 1000,
  $package_ensure          = present,
  $use_ssl                 = false,
  $ssl_no_verify           = false,
  $use_syslog              = false,
  $log_level               = 'WARNING',
  $django_session_engine   = 'django.contrib.sessions.backends.cache',
  $servername              = $::hostname,
  $cache_backend           = undef,
  $cache_options           = undef,
  $log_handler             = 'file',
  $custom_theme_path       = undef,
  $apache_options          = '-Indexes',
  $headers                 = ['set X-XSS-Protection "1; mode=block"',
                              'set X-Content-Type-Options nosniff',
                              'always append X-Frame-Options SAMEORIGIN'],
  $hypervisor_options      = {},
  $overview_days_range     = undef,
) {

  if $debug { #syslog and nondebug case
    #We don't realy want django debug, it is too verbose.
    $django_debug   = false
    $django_verbose = false
    $log_level_real = 'DEBUG'
  } elsif $verbose {
    $django_verbose = true
    $django_debug   = false
    $log_level_real = 'INFO'
  } else {
    $django_verbose = false
    $django_debug   = false
    $log_level_real = $log_level
  }

  # Apache and listen ports
  class { 'osnailyfacter::apache':
    listen_ports => hiera_array('apache_ports', ['80', '8888']),
  }

  class { '::horizon':
    bind_address          => $bind_address,
    cache_server_ip       => $cache_server_ip,
    cache_server_port     => $cache_server_port,
    cache_backend         => $cache_backend,
    cache_options         => $cache_options,
    secret_key            => $secret_key,
    package_ensure        => $package_ensure,
    horizon_app_links     => $horizon_app_links,
    keystone_url          => $keystone_url,
    keystone_default_role => $keystone_default_role,
    django_debug          => $django_debug,
    api_result_limit      => $api_result_limit,
    listen_ssl            => $use_ssl,
    ssl_no_verify         => $ssl_no_verify,
    log_level             => $log_level_real,
    configure_apache      => false,
    django_session_engine => $django_session_engine,
    allowed_hosts         => '*',
    secure_cookies        => false,
    log_handler           => $log_handler,
    neutron_options       => $neutron_options,
    custom_theme_path     => $custom_theme_path,
    redirect_type         => 'temp', # LP#1385133
    hypervisor_options    => $hypervisor_options,
    overview_days_range   => $overview_days_range,
  }

  # Performance optimization for wsgi
  if ($::memorysize_mb < 1200 or $::processorcount <= 3) {
    $wsgi_processes = 2
    $wsgi_threads = 9
  } else {
    $wsgi_processes = $::processorcount
    $wsgi_threads = 15
  }

  class { '::horizon::wsgi::apache':
    priority       => false,
    bind_address   => $bind_address,
    wsgi_processes => $wsgi_processes,
    wsgi_threads   => $wsgi_threads,
    listen_ssl     => $use_ssl,
    extra_params   => {
      add_listen      => false,
      custom_fragment => template('openstack/horizon/wsgi_vhost_custom.erb'),
      default_vhost   => true,
      headers         => $headers,
      options         => $apache_options,
      setenvif        => 'X-Forwarded-Proto https HTTPS=1',
    },
  } ~>
  Service[$::apache::params::service_name]

  # Chown dashboard dir
  $dashboard_directory = '/usr/share/openstack-dashboard/'
  $wsgi_user = $::horizon::params::apache_user
  $wsgi_group = $::horizon::params::apache_group

  exec { 'chown_dashboard' :
    command     => "chown -R ${wsgi_user}:${wsgi_group} ${dashboard_directory}",
    path        => [ '/usr/sbin', '/usr/bin', '/sbin', '/bin' ],
    refreshonly => true,
    provider    => 'shell',
  }

  Exec['refresh_horizon_django_cache'] ~> Exec['chown_dashboard']
}

