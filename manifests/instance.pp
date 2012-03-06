define wordpress::instance(
  $path = 'absent',
  $autoinstall = true,
  $blog_options = {},
  $uid_name = root,
  $gid_name = apache
) {
  require wordpress::base

  # create webdir
  # for the cloning, $documentroot needs to be absent
  git::clone {
    "git_clone_${name}" :
      git_repo => $git_repo,
      projectroot => $path,
      cloneddir_user => $uid_name,
      cloneddir_group => $gid_name,
      before => File[$path],
  }
  apache::vhost::file::documentrootdir {
    "wordpressgitdir_${name}" :
      ensure => $ensure,
      documentroot => $path,
      filename => '.git',
      thedomain => $name,
      owner => $uid_name,
      group => 'root',
      mode => 400,
  }
  if $autoinstall {

    $init_options = {
      'dbhost' => hiera('wordpress_default_dbhost','localhost'),
      'blogtitle' => $name,
      'lang' => 'de_DE',
      'public' => false,
      'admin_ssl' => true,
      'blogaddress' => "http://${name}",
      'adminuser' => 'admin',
      'adminpwd' => trocla("wordpress_adminuser_${name}",'plain')
    }
    $real_blog_options = merge($init_options, $blog_options)
    if !has_key($real_blog_options,'dbname') or !has_key($real_blog_options,'adminemail') {
      fail("blog_options for ${name} misses one of the following mandatory options: dbname, adminemail")
    }
    if !has_key($real_blog_options,'dbuser') {
      $real_blog_options['dbuser'] = $real_blog_options['dbname']
    }
    if !has_key($real_blog_options,'dbpwd') {
      $real_blog_options['dbpwd'] = trocla("mysql_${real_blog_options['dbuser']}",'plain')
    }
    $public_flag = $real_blog_options['public'] ? {
      true => '',
      default => '-P'
    }
    $admin_ssl = $real_blog_options['admin_ssl'] ? {
      true => '-s',
      default => ''
    }
    $lang_flag = $real_blog_options['lang'] ? {
      '' => '',
      false => '',
      undef => '',
      default => "-l ${real_blog_options['lang']}"
    }

    exec{
      "enable_writing_for_wordpress_${name}":
        command => "chmod 770 ${path}",
        unless => "test -f ${path}/wp-config.php",
        refreshonly => true,
        subscribe => Git::Clone["git_clone_${name}"],
        notify => Exec["install_wordpress_${name}"];

      "install_wordpress_${name}":
        command => "/var/www/wordpress_tools/installer/wordpress-cli-installer.sh -b ${real_blog_options['blogaddress']} -e ${real_blog_options['adminemail']} -p '${real_blog_options['adminpwd']}' ${public_flag} ${admin_ssl} -T ${real_blog_options['blogtitle']} -u ${real_blog_options['adminuser']} ${lang_flag} --dbuser=${real_blog_options['dbuser']} --dbpass=${real_blog_options['dbpass']} --dbname=${real_blog_options['dbname']} --dbhost=${real_blog_options['dbhost']} ${path}",
        unless => "test -f ${path}/wp-config.php",
        refreshonly => true,
        before => File[$path];
    }
  }
}
