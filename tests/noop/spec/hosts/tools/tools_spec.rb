require 'spec_helper'
require 'shared-examples'
manifest = 'tools/tools.pp'

tools = [
  'screen',
  'tmux',
  'htop',
  'tcpdump',
  'strace',
  'fuel-misc'
]

puppet = Noop.hiera('puppet')

describe manifest do
  shared_examples 'catalog' do
    it "should contain ssh host keygen exec for Debian OS only" do
      if facts[:osfamily] == 'Debian'
        should contain_exec('host-ssh-keygen').with(
          'command' => 'ssh-keygen -A'
        )
      else
        should_not contain_exec('host-ssh-keygen')
      end
    end

    it 'should declare tools classes' do
      should contain_class('osnailyfacter::atop')
      should contain_class('osnailyfacter::ssh')
      should contain_class('osnailyfacter::puppet_pull').with(
        'modules_source'   => puppet['modules'],
        'manifests_source' => puppet['manifests']
      )
    end

    it 'should declare osnailyfacter::acpid on virtual machines' do
      facts[:virtual] = 'kvm'
      should contain_class('osnailyfacter::acpid')
    end

    tools.each do |i|
      it do
        should contain_package(i).with({
          'ensure' => 'present'})
      end
    end

    it 'should install man package' do
      if facts[:osfamily] == 'Redhat'
        if facts[:operatingsystemmajrelease] >= 7
          should contain_package('man-db').with({'ensure' => 'present'})
        else
          should contain_package('man').with({'ensure' => 'present'})
        end
      end
    end

    it do
      should contain_package('cloud-init').with({
        'ensure' => 'absent'})
    end
  end

  test_ubuntu_and_centos manifest
end
