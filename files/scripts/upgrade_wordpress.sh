#!/bin/bash

function run_wp_cli {
  run_as $1 "${2}"
  if [ $? -gt 0 ]; then
    echo "FAILURE while running: $wp_cli ${cmd}"
    exit 1
  fi
}

function run_as {
  su -s /bin/bash $1 -c "${wp_cli} ${2}"
}

function usage {
  echo "USAGE: $0 wp-name-or-directory"
  exit 1
}

function update_wp {
  wp=$1
  if [[ $wp =~ ^\/ ]]; then
    wwwdir=$wp
  else
    wwwdir=/var/www/vhosts/$wp/www
  fi
  if [ -z $wp ] || [ ! -f $wwwdir/wp-config.php ]; then
    usage
  fi
  wp_cli="wp --path=${wwwdir} --no-color"
  user=$(stat -c%U $wwwdir)

  run_as $user "core is-installed" || (echo "No supported wordpress installed in ${wwwdir}..." && usage)

  echo "Starting updating  ${wp}..."
  run_as $user "core check-update" | grep -Eq '^Success:' > /dev/null
  if [ $? -gt 0 ]; then
    echo "Upgrading Wordpress core..."
    run_wp_cli $user "core update"
    run_wp_cli $user "core update-db"
  else
    echo "Core is up2date!"
  fi

  for i in plugin theme; do
    run_as $user "${i} update --all --dry-run" | grep -qE "^No ${i} updates available." > /dev/null
    if [ $? -gt 0 ]; then
      echo "Upgrading ${i}s..."
      run_wp_cli $user "${i} update --all"
    else
      echo "All ${i} up2date..."
    fi
  done

  echo "Updating ${wp} finished."
}

update_wp $1
