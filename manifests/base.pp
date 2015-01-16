# basic things for automated wordpress installations
class wordpress::base(
  $default_dbhost = 'localhost'
) {
  package{'wp-cli':
    ensure => present,
  }
}
