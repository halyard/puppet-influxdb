# @summary Configure InfluxDB instance
#
class influxdb (
  String $hostname,
  String $datadir,
  String $tls_account,
  Optional[String] $challengealias = undef,
) {
  file { ["${datadir}", "${datadir}/data", "${datadir}/certs"]:
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

  -> docker::container { 'influxdb':
    image => 'influxdb:latest',
    args  => "-p 127.0.0.1:8086:8086 -v ${datadir}/data:/var/lib/influxdb2 -v ${datadir}/config.yml:/etc/influxdb2/config.yml",
    cmd   => '',
  }
}
