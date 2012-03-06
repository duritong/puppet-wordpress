class wordpress::base(
  $mgmt_tools_git_repo = hiera('wordpress_mgmt_tools_git_repo','git://git.immerda.ch/wordpress-cli-installer.git')
) {
  file{'/var/www/wordpress_tools':
    ensure => directory,
    owner => root, group => 0, mode => 0640;
  }
  git::clone{"wordpress_mgmt_tools":
    git_repo => $wordpress::base::mgmt_tools_git_repo,
    projectroot => '/var/www/wordpress_tools/installer',
  }
}
