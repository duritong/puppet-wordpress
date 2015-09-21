# activated & installed plugin
define wordpress::instance::active_plugin(
  $user,
  $group,
  $path,
){
  $infos = split($name,'@')
  wordpress::instance::plugin{
    $name:
      user  => $user,
      group => $group,
      path  => $path,
  } ~> exec{"activate_plugin_${infos[0]}_wordpress_${infos[1]}":
    command     => "wp --path=${path} --no-color plugin activate ${infos[0]}",
    refreshonly => true,
    user        => $user,
    group       => $group,
    before      => Service['apache'];
  }
}
