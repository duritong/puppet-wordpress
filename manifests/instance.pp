# manage an automated wordpress installation
define wordpress::instance(
  $path,
  $autoinstall            = true,
  $blog_options           = {},
  $uid_name               = root,
  $gid_name               = apache,
  $php_installation       = 'system',
) {
  require wordpress::base
  $init_options = {
    'dbhost'            => $wordpress::base::default_dbhost,
    'blogtitle'         => $name,
    'lang'              => 'de_DE',
    'admin_ssl'         => true,
    'blogaddress'       => "http://${name}",
    'adminuser'         => 'admin',
    'installed_plugins' => [],
    'active_plugins'    => [],
  }
  $real_blog_options = merge($init_options, $blog_options)

  $wp_cli_base = "wp --path=${path} --no-color"
  if $php_installation == 'system' {
    $wp_cli = $wp_cli_base
  } else {
    $php_inst_class = regsubst($php_installation,'^scl','php')
    require "::php::scl::${php_inst_class}"
    $scl_name = getvar("php::scl::${php_inst_class}::scl_name")
    $wp_cli = "scl enable ${scl_name} -- ${wp_cli_base}"
  }
  $base = dirname($path)
  exec{"download_wp_${name}":
    command => "${wp_cli} core download --locale=${real_blog_options['lang']}",
    creates => "${path}/wp-login.php",
    user    => $uid_name,
    group   => $uid_name,
    require => File[$path],
  }

  if $autoinstall {
    if !('dbname' in $blog_options) or !('adminemail' in $blog_options) {
      fail("blog_options for ${name} misses one of the following mandatory \
options: dbname, adminemail")
    }
    if !('dbuser' in $blog_options) {
      $dbuser = $blog_options['dbname']
    } else {
      $dbuser = $blog_options['dbuser']
    }
    if !('dbpass' in $blog_options) {
      $dbpass = trocla("mysql_${dbuser}",'plain')
    } else {
      $dbpass = $blog_options['dbpass']
    }

    $def_install_options = {
      'dbuser'      => $dbuser,
      'dbpass'      => $dbpass,
      'adminpwd'    => trocla("wordpress_adminuser_${name}",'plain'),
    }
    $install_options = merge($def_install_options,$real_blog_options)

    $db_prefix_salt = "${install_options['dbuser']}${install_options['dbpass']}"
    $db_prefix = inline_template("<%= require 'digest/sha1'; \
'w'+Digest::SHA1.hexdigest('${db_prefix_salt}')[0..7]+'_' %>")
    exec{
      "config_wordpress_${name}":
        command     => "${wp_cli} core config \
--dbname=${install_options['dbname']} \
--dbuser=${install_options['dbuser']} \
--dbpass='${install_options['dbpass']}' \
--dbhost=${install_options['dbhost']} \
--dbprefix=${db_prefix} \
--locale=${install_options['lang']} \
--extra-php <<PHP
define('FORCE_SSL_ADMIN', ${install_options['admin_ssl']});
PHP
",
        refreshonly => true,
        creates     => "${path}/wp-config.php",
        user        => $uid_name,
        group       => $gid_name,
        subscribe   => Exec["download_wp_${name}"],
        notify      => Exec["install_wordpress_${name}"];
      "install_wordpress_${name}":
        command     => "${wp_cli} core install \
--url=${install_options['blogaddress']} \
--title='${install_options['blogtitle']}' \
--admin_user=${install_options['adminuser']} \
--admin_password='${install_options['adminpwd']}' \
--admin_email=${install_options['adminemail']}",
        refreshonly => true,
        user        => $uid_name,
        group       => $gid_name;
      "disable_gravatars_${name}":
        command     => "${wp_cli} option set show_avatars 0",
        refreshonly => true,
        user        => $uid_name,
        group       => $gid_name,
        subscribe   => Exec["install_wordpress_${name}"],
        before      => Service['apache'];
      # the installer creates certain dirs, make sure they are writeable
      "fix_upload_perms_${name}":
        command     => "chmod -R g+w ${path}/wp-content/uploads",
        refreshonly => true,
        user        => $uid_name,
        group       => $gid_name,
        subscribe   => Exec["install_wordpress_${name}"],
        before      => Service['apache'];
    }
    # make sure we have the local grants done before installing wp
    $dbhost = $install_options['dbhost']
    if $dbhost  in ['localhost','127.0.0.1','::1'] {
      $dbname = $install_options['dbname']
      Mysql_grant<| title == "${dbuser}@${dbhost}/${dbname}" |> -> Exec["config_wordpress_${name}"]
    }

    $installed_plugins = suffix(union($install_options['installed_plugins'],
      $wordpress::base::default_installed_plugins),"@${name}")
    if !empty($installed_plugins) {
      wordpress::instance::plugin{
        $installed_plugins:
          path  => $path,
          user  => $uid_name,
          group => $gid_name,
      }
    }
    $active_plugins = suffix(union($install_options['active_plugins'],
      $wordpress::base::default_active_plugins),"@${name}")
    if !empty($active_plugins) {
      wordpress::instance::active_plugin{
        $active_plugins:
          path  => $path,
          user  => $uid_name,
          group => $gid_name,
      }
    }
  }
}
