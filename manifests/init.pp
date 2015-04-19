# Copyright 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# == Class: simpleproxy
#
class puppet (
  $pin_puppet            = '3.',
  $enable_puppet         = false,
  $http_proxy            = undef,
  $agent_http_proxy_host = undef,
  $agent_http_proxy_port = undef,
  $https_proxy           = undef,
  $certname              = $::fqdn,
  $puppetmaster_server   = 'puppetmaster.openstack.org',
  $puppet_ca_server      = undef,
  $dns_alt_names         = undef,
  $environment_path      = '/etc/puppet/environments',
  $basemodule_path       = '/etc/puppet/modules',
  $environment_timeout   = 0,
  $store_configs         = true,
  $store_backend         = 'puppetdb',
  $reports               = 'store,puppetdb',
  $agent_runinterval     = 600,
  $puppet_release        = $::lsbdistcodename,
) {

  # pin facter and puppetdb according to puppet version
  case $pin_puppet {
    '2.7.': {
      $pin_facter = '1.'
      $pin_puppetdb = '1.'
    }
    /^3\./: {
      $pin_facter = '2.'
      $pin_puppetdb = '2.'
    }
    default: {
      fail("Puppet version ${pin_puppet} not supported")
    }
  }

  # special hiera install for Fedora OS
  if ($::operatingsystem == 'Fedora') {

    package { 'hiera':
      ensure   => latest,
      provider => 'gem',
    }

    exec { 'symlink hiera modules' :
      command     => 'ln -s /usr/local/share/gems/gems/hiera-puppet-* /etc/puppet/modules/',
      path        => '/bin:/usr/bin',
      subscribe   => Package['hiera'],
      refreshonly => true,
    }

  }

  # Which Puppet do I take?
  # Take $pin_puppet and pin to that version
  if ($::osfamily == 'Debian') {
    # check version - trusty only has puppet 3
    if ($::lsbdistcodename == 'trusty') and ($pin_puppet == '2.7.') {
      fail('Puppet 2.7 version not supported')
    }

    apt::source { 'puppetlabs':
      location   => 'http://apt.puppetlabs.com',
      repos      => 'main',
      key        => '4BD6EC30',
      key_server => 'pgp.mit.edu',
      release    => $puppet_release,
    }

    file { '/etc/apt/apt.conf.d/80retry':
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      source  => 'puppet:///modules/puppet/80retry',
      replace => true,
    }

    file { '/etc/apt/apt.conf.d/90no-translations':
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      source  => 'puppet:///modules/puppet/90no-translations',
      replace => true,
    }

    file { '/etc/apt/preferences.d/00-puppet.pref':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      content => template('puppet/00-puppet.pref.erb'),
      replace => true,
    }

    file { '/etc/default/puppet':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      content => template('puppet/puppet.default.erb'),
      replace => true,
    }

  }

  if ($::osfamily == 'RedHat') {
    # check version - 7 only has puppet 3
    if ($::operatingsystemmajrelease == 7) and ($pin_puppet == '2.7.') {
      fail('Puppet 2.7 version not supported')
    }

    file { '/etc/yum.repos.d/puppetlabs.repo':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      content => template('puppet/centos-puppetlabs.repo.erb'),
      replace => true,
    }
    file { '/etc/yum.conf':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      source  => 'puppet:///modules/puppet/yum.conf',
      replace => true,
    }
  }

  file { '/etc/puppet/puppet.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('puppet/puppet.conf.erb'),
    replace => true,
  }

  # properly install package if not present
  if ! defined(Package[puppet]) {
    package { 'puppet':
      ensure => latest,
    }
  }

  # start puppet depending on settings
  if $enable_puppet != false {
    service { 'puppet':
      ensure => running,
      enable => true,
    }
  }
  else {
    service { 'puppet':
      ensure => stopped,
      enable => false,
    }
  }
}

