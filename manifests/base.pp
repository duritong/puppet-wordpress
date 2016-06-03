# basic things for automated wordpress installations
class wordpress::base(
  $default_dbhost            = '127.0.0.1',
  $default_active_plugins    = [ 'si-captcha-for-wordpress',
    'disable-google-fonts' ],
  $default_installed_plugins = [ 'wp-super-cache', 'backupwordpress', ],
) {
  package{'wp-cli':
    ensure => present,
  } -> file{'/usr/local/bin/upgrade_wordpress':
    source => 'puppet:///modules/wordpress/scripts/upgrade_wordpress.sh',
    owner  => root,
    group  => 0,
    mode   => '0755';
  }
  # cleanup old file
  file{'/usr/local/sbin/upgrade_wordpress':
    ensure => absent,
  }
  require mysql::client
  # this is now a valid binary
  concat::fragment{'wordpress_binary':
    target  => '/etc/rkhunter.conf.local',
    content => "RTKT_FILE_WHITELIST=/usr/bin/wp\n",
  }
}
