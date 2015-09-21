# install additional plugins
define wordpress::instance::plugin(
  $user,
  $group,
  $path,
){
  $infos = split($name,'@')
  exec{"install_plugin_${infos[0]}_wordpress_${infos[1]}":
    command     => "wp --path=${path} --no-color plugin install ${infos[0]}",
    refreshonly => true,
    user        => $user,
    group       => $group,
    subscribe   => Exec["install_wordpress_${infos[1]}"],
    before      => Service['apache'];
  }
}
