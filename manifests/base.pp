# basic things for automated wordpress installations
class wordpress::base(
  $default_dbhost = 'localhost'
) {
  package{'wp-cli':
    ensure => present,
  } -> file{'/usr/local/sbin/upgrade_wordpress':
    source => 'puppet:///modules/wordpress/scripts/upgrade_wordpress.sh',
    owner  => root,
    group  => 0,
    mode   => '0700';
  }
  require mysql::client
}
