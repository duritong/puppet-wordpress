# install additional plugins
define wordpress::instance::plugin(
  $wp_name,
  $user,
  $group,
  $path,
){
  exec{"install_plugin_${name}_wordpress_${wp_name}":
    command     => "wp-cli --path=${path} --no-color plugin install ${name}",
    refreshonly => true,
    user        => $user,
    group       => $group,
    subscribe   => Exec["install_wordpress_${name}"],
    before      => File[$path];
  }
}
