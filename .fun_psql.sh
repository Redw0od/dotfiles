
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "psql" "vault")
abbr='psql'
# Gives details on functions in this file
# Call with a function's name for more information
eval "${abbr}-help () {
  local func=\"\${1}\"
  local func_names=\"\$(cat ${_this} | grep '^${abbr}-' | awk '{print \$1}')\"
  if [ -z \"\${func}\" ]; then
    echo \"Helpful Elasticsearch functions.\"
    echo \"For more details: \${color[green]}${abbr}-help [function]\${color[default]}\"
    echo \"\${func_names[@]}\"
    return
  fi
  cat \"${_this}\" | \
  while read line; do
		if [ -n \"\$(echo \"\${line}\" | grep -F \"\${func} ()\" )\" ]; then
      banner \" function: \$func \" \"\" \${color[gray]} \${color[green]}
      echo -e \"\${comment}\"
    fi
    if [ ! -z \"\$(echo \${line} | grep '^#')\" ]; then 
      if [ ! -z \"\$(echo \${comment} | grep '^#')\" ]; then
        comment=\"\${comment}\n\${line}\"
      else
        comment=\"\${line}\"
      fi
    else
      comment=\"\"
    fi
  done  
  banner \"\" \"\" \${color[gray]}
}"

# Create User for DB permissions if it doesnt exist
# declare -A ARRAY; psql-parse-access-privs ARRAY "{=CT/role,user=C/role}"
psql-parse-access-privs () {
    local -n OUT_ARRAY=${1}
    local ACL=${2:1:-1}
    declare -a ACL_ARRAY=()
    IFS=','; read -ra ACL_ARRAY <<< ${ACL}
    IFS=${IFS_BACKUP}
    for element in "${ACL_ARRAY[@]}"; do 
        local role="$(echo ${element} | cut -d "=" -f 2)"
        local db_username="$(echo ${element} | cut -d "=" -f 1)"
        OUT_ARRAY+=([${db_username:-PUBLIC}]="${role}")
    done
}

# Convert Postgres priviledge shorthand to SQL Statements
# psql-privs-to-command "cCT/role"
psql-privs-to-command () {
    local acl=${1}
    local code=${1%/*}
    local role=${1#*/}
    local command=""
    for char in $(echo ${code} | fold -w 1); do 
      case $char in
        r)
          command="$command SELECT,"
        ;;
        w)
          command="$command UPDATE,"
        ;;
        a)
          command="$command INSERT,"
        ;;
        d)
          command="$command DELETE,"
        ;;
        D)
          command="$command TRUNCATE,"
        ;;
        x)
          command="$command REFERENCES,"
        ;;
        t)
          command="$command TRIGGER,"
        ;;
        X)
          command="$command EXECUTE,"
        ;;
        U)
          command="$command USAGE,"
        ;;
        C)
          command="$command CREATE,"
        ;;
        c)
          command="$command CONNECT,"
        ;;
        T)
          command="$command TEMPORARY,"
        ;;
      esac
    done
    echo "${command:1:-1}"
}

# Create empty DB with specific Owner if it doesnt exist
create-db () {
  local db="${1}"
  local owner="${2}"
  local dms_user="${3}"
  local target_server="${4}"
  local source_admin="${5}"
    if [ ! "$(psql -U ${dms_user} -h ${target_server} -c "SELECT datname FROM pg_database WHERE datname='${db}'" -A -t -d postgres)" ]; then
        echo "CREATE DATABASE ${db} OWNER ${owner}"
        if [[ "${owner}" != "${source_admin}" ]]; then
            psql -U ${dms_user} -h "${target_server}" -c "GRANT ${owner} TO ${dms_user};" -d postgres
        fi
        psql -U ${dms_user} -h "${target_server}" -c "CREATE DATABASE ${db} OWNER ${owner};" -d postgres
        psql -U ${dms_user} -h "${target_server}" -c "GRANT ALL ON DATABASE \"${db}\" TO \"${owner}\";" -d postgres
        psql -U ${dms_user} -h "${target_server}" -c "GRANT ALL ON DATABASE \"${db}\" TO \"${source_admin}\";" -d postgres
        if [[ "${owner}" != "${source_admin}" ]]; then
            psql -U ${dms_user} -h "${target_server}" -c "REVOKE ${owner} from ${dms_user};" -d postgres
        fi
    fi
    psql -U ${dms_user} -h "${target_server}" -c "REVOKE ALL ON DATABASE \"${db}\" FROM PUBLIC;" -d postgres
}

# Connect you to a RDS database, defaults to repond user
# psql-connect <host> [username] [password]
psql-connect () {
  local host="${1}"
  local username="${2:-respond}"
  local password=${3:-$(vault-rds-lookup)}
  export PGPASSWORD=${password}
  psql -U ${username} -h ${host} -d ${username}
}

# Create User for DB permissions if it doesnt exist
create-user () {
  local user="${1}"
    if [[ "${user}" == "${SOURCE_ADMIN_USER}" || "${user}" == "${TARGET_ADMIN_USER}" || "${user}" == "${DMS_USER}" ]]; then
        return
    fi
    if [ ! "$(psql -U ${DMS_USER} -h ${TARGET_SERVER} -c "SELECT usename FROM pg_user WHERE usename='${user}'" -A -F"," -t -d postgres)" ]; then
        local rds_secret=$(vault kv get -field=password ${VAULT_PATH}/${user}/secret/rds/ 2> /dev/null)
        if [ -z "${rds_secret}" ]; then 
            vt legacy
            rds_secret=$(vault read ${VAULT_PATH}/${user}/secret/rds/ | awk /'password/ {print $2}' 2> /dev/null)
            vt primary
        fi
        if [ -z "${rds_secret}" ]; then 
            echo "ERROR DETECTED for ${user}"
            ERROR_LIST+=("${user}")
        fi
        echo "CREATE ROLE \"${user}\" WITH PASSWORD '${rds_secret}' LOGIN"
        echo "CREATE ROLE \"${user}_read_only\" WITH PASSWORD '${rds_secret}'"
        psql -U ${DMS_USER} -h "${TARGET_SERVER}" -c "CREATE ROLE \"${user}\" WITH PASSWORD '${rds_secret}' LOGIN" -d postgres
        psql -U ${DMS_USER} -h "${TARGET_SERVER}" -c "CREATE ROLE \"${user}_read_only\" WITH PASSWORD '${rds_secret}'" -d postgres
    fi
}

create-source-admin-user () {
    local suser="${1}"
    local spass="${2}"
    if [ ! "$(psql -U ${SOURCE_ADMIN_USER} -h ${SOURCE_SERVER} -c "SELECT usename FROM pg_user WHERE usename='${suser}'" -A -t -d postgres)" ]; then
        echo "CREATE ROLE \"${suser}\" WITH IN GROUP \"rds_superuser\" PASSWORD '${spass}' VALID UNTIL 'infinity' CREATEDB CREATEROLE LOGIN;"
        psql -U ${SOURCE_ADMIN_USER} -h "${SOURCE_SERVER}" -c "CREATE ROLE \"${suser}\" WITH IN GROUP \"rds_superuser\" PASSWORD '${spass}' VALID UNTIL 'infinity' CREATEDB CREATEROLE LOGIN;" -d postgres
    fi
    if [ ! "$(psql -U ${SOURCE_ADMIN_USER} -h ${SOURCE_SERVER} -c "SELECT rolname FROM pg_roles WHERE pg_has_role( '${suser}', oid, 'member');" -A -t -d postgres | grep ${SOURCE_ADMIN_USER})" ]; then
        echo "GRANT \"${SOURCE_ADMIN_USER}\" TO \"${suser}\";"
        psql -U ${SOURCE_ADMIN_USER} -h "${SOURCE_SERVER}" -c "GRANT \"${SOURCE_ADMIN_USER}\" TO \"${suser}\";" -d postgres
    fi
}

create-target-admin-user () {
    local suser="${1}"
    local spass="${2}"
    if [ ! "$(psql -U ${TARGET_ADMIN_USER} -h ${TARGET_SERVER} -c "SELECT usename FROM pg_user WHERE usename='${suser}'" -A -t -d postgres)" ]; then
        echo "CREATE ROLE \"${suser}\" WITH IN GROUP \"rds_superuser\" PASSWORD '${spass}' VALID UNTIL 'infinity' CREATEDB CREATEROLE LOGIN;"
        psql -U ${TARGET_ADMIN_USER} -h "${TARGET_SERVER}" -c "CREATE ROLE \"${suser}\" WITH IN GROUP \"rds_superuser\" PASSWORD '${spass}' VALID UNTIL 'infinity' CREATEDB CREATEROLE LOGIN;" -d postgres
    fi
    if [ ! "$(psql -U ${TARGET_ADMIN_USER} -h ${TARGET_SERVER} -c "SELECT rolname FROM pg_roles WHERE pg_has_role( '${suser}', oid, 'member');" -A -t -d postgres | grep ${SOURCE_ADMIN_USER})" ]; then
        echo "GRANT \"${SOURCE_ADMIN_USER}\" TO \"${suser}\";"
        psql -U ${TARGET_ADMIN_USER} -h "${TARGET_SERVER}" -c "GRANT \"${SOURCE_ADMIN_USER}\" TO \"${suser}\";" -d postgres
    fi
}

psql-grant-db-access () {
    local db_username="${1}"
    local database="${2}"
    local acl="$(psql-privs-to-command ${3})"
    echo "GRANT ${acl:-ALL} ON DATABASE \"${database}\" TO \"${db_username}\";"
}

psql-grant-table-access () {
    local db_username="${1}"
    local table="${2}"
    local schema="${3}"
    local acl="$(psql-privs-to-command ${4})"
    echo "GRANT ${acl:-ALL} ON \"${table}\" IN \"${schema:-PUBLIC}\" TO \"${db_username}\";"
}

 # vault-profile legacy
 # local pass=$(vault read ${VAULT_PATH}/shared_context/secret/rds/ | awk /'password/ {print $2}' 2> /dev/null)
psql-query-shared () {
  local query="${1}"
  local user="${2:-shared_context}"
  local pass="${3}"
  local pgpass=${PGPASSWORD}
  export PGPASSWORD="${pass}"
  psql -h ${RDS[prod-shared-context]} -U ${user} -c "${query}"
  export PGPASSWORD="${pgpass}"
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi