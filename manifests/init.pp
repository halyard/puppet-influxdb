# @summary Configure InfluxDB instance
#
# @param hostname sets the hostname for influxdb
# @param datadir sets where the data is persisted
# @param tls_account sets the TLS account config
# @param tls_challengealias sets the alias for TLS cert
# @param container_ip sets the address of the Docker container
class influxdb (
  String $hostname,
  String $datadir,
  String $tls_account,
  Optional[String] $tls_challengealias = undef,
  String $container_ip = '172.17.0.2',
) {
  file { ["${datadir}/data", "${datadir}/certs"]:
    ensure => directory,
  }

  -> file { "${datadir}/config.yml":
    ensure  => file,
    content => template('influxdb/config.yml.erb'),
  }

  -> acme::certificate { $hostname:
    reloadcmd      => '/usr/bin/systemctl restart container@influxdb',
    keypath        => "${datadir}/certs/key",
    fullchainpath  => "${datadir}/certs/cert",
    account        => $tls_account,
    challengealias => $tls_challengealias,
  }

  -> firewall { '100 dnat for influxdb':
    chain  => 'DOCKER_EXPOSE',
    jump   => 'DNAT',
    proto  => 'tcp',
    dport  => 443,
    todest => "${container_ip}:8086",
    table  => 'nat',
  }

  -> docker::container { 'influxdb':
    image => 'influxdb:latest',
    args  => [
      "--ip ${container_ip}",
      "-v ${datadir}/data:/var/lib/influxdb2",
      "-v ${datadir}/config.yml:/etc/influxdb2/config.yml",
      "-v ${datadir}/certs:/mnt/certs",
    ],
    cmd   => '',
  }
}
