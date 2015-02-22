# basic things for automated wordpress installations
class wordpress::base(
  $default_dbhost            = 'localhost',
  $default_active_plugins    = [ 'si-captcha-for-wordpress',
    'disable-google-fonts' ],
  $default_installed_plugins = [ 'wp-super-cache', 'backupwordpress', ],
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
