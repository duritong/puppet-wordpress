#!/bin/bash

function run_wp_hard {
  run_wp "${1}"
  if [ $? -gt 0 ]; then
    echoerr "FAILURE while running: ${wp_cli} ${1}"
    exit 1
  fi
}

function run_wp {
  run "${wp_cli} ${1}"
}

function run_hard {
  run "${1}"
  if [ $? -gt 0 ]; then
    echoerr "FAILURE while running: ${1}"
    exit 1
  fi
}
# run detects whether it must switch or not
# so we can run it also an unpriviledged user
function run {
  if [ "${current_user}" == 'root' ]; then
    su - -s /bin/bash $run_user -c "${1}"
  elif [ "${current_user}" == "${run_user}" ]; then
    $1
  else
    echoerr "Cannot run as other user (${run_user}) if not running as root"
    exit 1
  fi
}

function usage {
  echoerr "USAGE: ${0} wp-name-or-directory"
  exit 1
}

function echoerr {
  echo "$@" 1>&2
}

function wp_backup {
  echo "Preparing backup..."
  run_wp "plugin list" | grep -q 'backupwordpress' > /dev/null
  if [ $? -gt 0 ]; then
    echo "Installing backup plugin"
    run_wp_hard "plugin install backupwordpress"
  fi
  activate_backup=0
  run_wp "plugin list" | grep -q 'backupwordpress' | grep -q 'active' > /dev/null
  if [ $? -gt 0 ]; then
    echo "Activating backup plugin"
    run_wp_hard "plugin activate backupwordpress"
  activate_backup=1
  fi
  echo "Cleanup previous backups ${backup_dir}"
  run_hard "tmpwatch -m -q 1d ${backup_dir}"

  echo "Making the backup..."
  # exclude the default backup path
  run_wp_hard "backupwordpress backup --destination=${backup_dir} --excludes='wp-content/backupwordpress-*'"
  # only deactivate if we updated it
  # otherwise we assume the user has it activated and configured
  if [ $activate_backup -gt 0 ]; then
    echo "Deactivating backup plugin"
    run_wp_hard "plugin deactivate backupwordpress"
  fi
  backup_done=1
}

function ensure_wp_backup {
  [ $backup_done -gt 0 ] || wp_backup
}

function update_wp {
  echo "Starting updating  ${wp}..."
  run_wp "core check-update" | grep -Eq '^Success:' > /dev/null
  if [ $? -gt 0 ]; then
    wp_backup
    echo "Upgrading Wordpress core..."
    run_wp_hard "core update"
    run_wp_hard "core update-db"
  else
    echo "Core is up2date!"
  fi

  for i in plugin theme; do
    run_wp "${i} update --all --dry-run" | grep -qE "^No ${i} updates available." > /dev/null
    if [ $? -gt 0 ]; then
      ensure_wp_backup
      echo "Upgrading ${i}s..."
      run_wp_hard "${i} update --all"
    else
      echo "All ${i} up2date..."
    fi
  done

  echo "Updating language"
  run_wp "core language update --dry-run" | grep -qE '^Success: Translations updates are not needed'
  if [ $? -gt 0 ]; then
    ensure_wp_backup
    echo "Upgrading active language..."
    run_wp_hard "core language update"
  else
    echo "Language is up2date!"
  fi

  echo "Updating ${wp} finished."
}

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
run_user=$(stat -c%U $wwwdir)
current_user=$(id -un)
backup_done=0

run_wp "core is-installed" || (echoerr "No supported wordpress installed in ${wwwdir}..." && usage)

user_home=$(eval echo "~${run_user}")
backup_dir="${user_home}/private/wp_update_backup"
[ -d $backup_dir ] || run_hard "mkdir $backup_dir"

update_wp $wp
