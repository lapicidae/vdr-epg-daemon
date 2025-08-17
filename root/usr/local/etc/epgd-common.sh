# shellcheck shell=bash
# shellcheck disable=SC2034
# /usr/local/etc/epgd-common.sh

# ----------------------------------------------------------------------------
# Variables for the EPGd script colletion
#
# Autor: Lapicidae (https://github.com/lapicidae)
# ----------------------------------------------------------------------------


# Determine the correct database client
DB_CLIENT=$(command -v mariadb || command -v mysql || true)

if [ -z "$DB_CLIENT" ]; then
    printf '\nERROR: Neither "mariadb" nor "mysql" client found. Please install one of these tools.\n' >&2
    exit 1
fi


EPGD_CONF=${EPGD_CONF:-"/etc/epgd/epgd.conf"}

# Read values from epgd.conf into temporary variables.
epgd_host_from_conf=""
epgd_port_from_conf=""
epgd_db_from_conf=""
epgd_user_from_conf=""
epgd_pw_from_conf=""

if [ -r "$EPGD_CONF" ]; then
	# Extract values, stripping whitespace and comments. The `tr` command is used to remove carriage returns from Windows-style line endings.
	epgd_host_from_conf=$(grep -E '^DbHost *= *' "$EPGD_CONF" | sed -E 's/^DbHost *= *(.*)/\1/' | tr -d '\r')
	epgd_port_from_conf=$(grep -E '^DbPort *= *' "$EPGD_CONF" | sed -E 's/^DbPort *= *(.*)/\1/' | tr -d '\r')
	epgd_db_from_conf=$(grep -E '^DbName *= *' "$EPGD_CONF" | sed -E 's/^DbName *= *(.*)/\1/' | tr -d '\r')
	epgd_user_from_conf=$(grep -E '^DbUser *= *' "$EPGD_CONF" | sed -E 's/^DbUser *= *(.*)/\1/' | tr -d '\r')
	epgd_pw_from_conf=$(grep -E '^DbPass *= *' "$EPGD_CONF" | sed -E 's/^DbPass *= *(.*)/\1/' | tr -d '\r')
fi

# Set final variables with a fallback logic: Command line > Config file > Hardcoded default.
MYSQL_HOST=${MYSQL_HOST:-${epgd_host_from_conf:-localhost}}
MYSQL_PORT=${MYSQL_PORT:-${epgd_port_from_conf:-0}}
EPGDB=${EPGDB:-${epgd_db_from_conf:-epg2vdr}}
EPGDB_USER=${EPGDB_USER:-${epgd_user_from_conf:-epg2vdr}}
MYSQL_PWD=${MYSQL_PWD:-${epgd_pw_from_conf:-epg}}

# Export password for the MySQL/MariaDB client
export MYSQL_PWD

# Execute DB command as user
if [ "$MYSQL_PORT" -ne 0 ] && [ "$MYSQL_PORT" -ne 3306 ]; then
 	# DB_USER_COMMAND="${DB_CLIENT} --host=${MYSQL_HOST} --port=${MYSQL_PORT} --user=${EPGDB_USER} --password=${MYSQL_PWD} --database=${EPGDB} --skip-ssl -e"
 	DB_USER_COMMAND="${DB_CLIENT} --host=${MYSQL_HOST} --port=${MYSQL_PORT} --user=${EPGDB_USER} --password=${MYSQL_PWD} --database=${EPGDB} -e"
else
 	DB_USER_COMMAND="${DB_CLIENT} --host=${MYSQL_HOST} --user=${EPGDB_USER} --database=${EPGDB} -e"
fi

EPGD_HOST=${EPGD_HOST:-localhost}
EPGD_PORT=${EPGD_PORT:-9999}


# vim: ts=4 sw=4 noet:
# kate: space-indent off; indent-width 4; mixed-indent off;
