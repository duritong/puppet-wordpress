# activated & installed plugin
define wordpress::instance::active_plugin(
  $wp_cli,
  $user,
  $group,
  $path,
){
  $infos = split($name,'@')
  wordpress::instance::plugin{
    $name:
      wp_cli => $wp_cli,
      user   => $user,
      group  => $group,
      path   => $path,
  } ~> exec{"activate_plugin_${infos[0]}_wordpress_${infos[1]}":
    command     => "${wp_cli} plugin activate ${infos[0]}",
    refreshonly => true,
    user        => $user,
    group       => $group,
    before      => Service['apache'];
  }
}
