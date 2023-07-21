# @summary Configure InfluxDB instance
#
# @param hostname sets the hostname for influxdb
# @param datadir sets where the data is persisted
# @param aws_access_key_id sets the AWS key to use for Route53 challenge
# @param aws_secret_access_key sets the AWS secret key to use for the Route53 challenge
# @param email sets the contact address for the certificate
# @param container_ip sets the address of the Docker container
# @param backup_target sets the target repo for backups
# @param backup_watchdog sets the watchdog URL to confirm backups are working
# @param backup_password sets the encryption key for backup snapshots
# @param backup_environment sets the env vars to use for backups
# @param backup_rclone sets the config for an rclone backend
class influxdb (
  String $hostname,
  String $datadir,
  String $aws_access_key_id,
  String $aws_secret_access_key,
  String $email,
  String $container_ip = '172.17.0.2',
  Optional[String] $backup_target = undef,
  Optional[String] $backup_watchdog = undef,
  Optional[String] $backup_password = undef,
  Optional[Hash[String, String]] $backup_environment = undef,
  Optional[String] $backup_rclone = undef,
) {
  $hook_script =  "#!/usr/bin/env bash
cp \$LEGO_CERT_PATH ${datadir}/certs/cert
cp \$LEGO_CERT_KEY_PATH ${datadir}/certs/key
/usr/bin/systemctl restart container@influxdb"

  file { [$datadir, "${datadir}/data", "${datadir}/certs"]:
    ensure => directory,
  }

  -> file { "${datadir}/config.yml":
    ensure  => file,
    content => template('influxdb/config.yml.erb'),
  }

  -> acme::certificate { $hostname:
    hook_script           => $hook_script,
    aws_access_key_id     => $aws_access_key_id,
    aws_secret_access_key => $aws_secret_access_key,
    email                 => $email,
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
      source        => "${datadir}/data",
      target        => $backup_target,
      watchdog_url  => $backup_watchdog,
      password      => $backup_password,
      environment   => $backup_environment,
      rclone_config => $backup_rclone,
    }
  }
}
