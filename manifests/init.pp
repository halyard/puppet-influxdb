# @summary Configure InfluxDB instance
#
# @param hostname sets the hostname for influxdb
# @param datadir sets where the data is persisted
# @param tls_account sets the TLS account config
# @param tls_challengealias sets the alias for TLS cert
# @param container_ip sets the address of the Docker container
# @param backup_target sets the target repo for backups
# @param backup_watchdog sets the watchdog URL to confirm backups are working
# @param backup_password sets the encryption key for backup snapshots
# @param backup_environment sets the env vars to use for backups
# @param backup_rclone sets the config for an rclone backend
class influxdb (
  String $hostname,
  String $datadir,
  String $tls_account,
  Optional[String] $tls_challengealias = undef,
  String $container_ip = '172.17.0.2',
  Optional[String] $backup_target = undef,
  Optional[String] $backup_watchdog = undef,
  Optional[String] $backup_password = undef,
  Optional[Hash[String, String]] $backup_environment = undef,
  Optional[String] $backup_rclone = undef,
) {
  file { [$datadir, "${datadir}/data", "${datadir}/certs"]:
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

  if $backup_target != '' {
    backup::repo { 'influxdb':
      source         => "${datadir}/data",
      target         => $backup_target,
      watchdog_url   => $backup_watchdog,
      password       => $backup_password,
      environment    => $backup_environment,
      rclone_options => $backup_rclone,
    }
  }
}
