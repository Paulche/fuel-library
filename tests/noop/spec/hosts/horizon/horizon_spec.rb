require 'spec_helper'
require 'shared-examples'
manifest = 'horizon/horizon.pp'

describe manifest do
  shared_examples 'catalog' do

    let(:network_scheme) do
      Noop.hiera_hash 'network_scheme'
    end

    let(:service_endpoint) do
      Noop.hiera 'service_endpoint'
    end

    let(:prepare) do
      Noop.puppet_function 'prepare_network_config', network_scheme
    end

    let(:bind_address) do
      prepare
      Noop.puppet_function 'get_network_role_property', 'horizon', 'ipaddr'
    end

    let(:nova_quota) do
      Noop.hiera 'nova_quota'
    end

    let(:keystone_url) do
      "http://#{service_endpoint}:5000/v2.0"
    end

    let(:cache_options) do
      {
          'SOCKET_TIMEOUT' => 1,
          'SERVER_RETRIES' => 1,
          'DEAD_RETRY'     => 1,
      }
    end

    ###########################################################################

    it 'should declare openstack::horizon class' do
      should contain_class('openstack::horizon').with(
                 'hypervisor_options' => {'enable_quotas' => nova_quota},
                 'bind_address' => bind_address
             )
    end

    it 'should declare openstack::horizon class with keystone_url' do
      should contain_class('openstack::horizon').with(
                 'keystone_url' => keystone_url
             )
    end

    it 'should declare horizon class with correct values' do
      should contain_class('horizon').with(
                 'cache_backend'       => 'django.core.cache.backends.memcached.MemcachedCache',
                 'cache_options'       => cache_options,
                 'log_handler'         => 'file',
                 'overview_days_range' => 1,
             )
    end

    context 'with Neutron DVR', :if => Noop.hiera_structure('neutron_advanced_configuration/neutron_dvr') do
      it 'should configure horizon for neutron DVR' do
        should contain_class('openstack::horizon').with(
                   'neutron_options' => {
                       'enable_distributed_router' => Noop.hiera_structure('neutron_advanced_configuration/neutron_dvr')
                   }
               )
      end
    end

    it {
      should contain_service('httpd').with(
           'hasrestart' => true,
           'restart'    => 'sleep 30 && apachectl graceful || apachectl restart'
      )
    }

    it {
      should contain_class('openstack::horizon').that_comes_before(
        'Haproxy_backend_status[keystone-admin]'
      )
    }

    it {
      should contain_class('openstack::horizon').that_comes_before(
        'Haproxy_backend_status[keystone-public]'
      )
    }

    it "should handle openstack-dashboard-apache package based on osfamily" do
      if facts[:osfamily] == 'Debian'
        should contain_package('openstack-dashboard-apache').with_ensure('absent')
      else
        should_not contain_package('openstack-dashboard-apache')
      end
    end
  end

  test_ubuntu_and_centos manifest
end

