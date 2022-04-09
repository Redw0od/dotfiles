
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("aws" "echo" "awk" "grep" "date" "expr" "jq" "column" "base64" "cut" "rev" "sleep")
abbr='aws'

# Create help function for this file
common-help "${abbr}" "${_this}"

# PS1 output for AWS profile
aws-ps1-color() {
  case "${AWS_PROFILE}" in
    *prod*)
      echo -e "${color[red]}${BOLD}${AWS_PROFILE}${color[blue]}"
      ;;
    *stage*)
      echo -e "${color[mustard]}${AWS_PROFILE}${color[blue]}"
      ;;
    *dev*)
      echo -e "${color[yellow]}${AWS_PROFILE}${color[blue]}"
      ;;
    *)
      echo -e "${color[orange]}${AWS_PROFILE}${color[blue]}"
      ;;
  esac
}

# Copy AWS session details to temp file
# Pass profile name as an argument
aws-save() {
  local suffix="-${1:-$AWS_PROFILE}"
  local session_file="/tmp/aws-session${suffix}"
  echo "export AWS_ACCESS_KEY_ID=\"$AWS_ACCESS_KEY_ID\"" > ${session_file}
  echo "export AWS_PROFILE=\"$AWS_PROFILE\"" >> ${session_file}
  echo "export AWS_SECRET_ACCESS_KEY=\"$AWS_SECRET_ACCESS_KEY\"" >> ${session_file}
  echo "export AWS_SECURITY_TOKEN=\"$AWS_SECURITY_TOKEN\"" >> ${session_file}
  echo "export AWS_SESSION_TOKEN=\"$AWS_SESSION_TOKEN\"" >> ${session_file}
  echo "export AWS_SESSION_TIME=\"$(date +%s)\"" >> ${session_file}
  export AWS_SESSION_TIME="$(date +%s)"
}

# Load AWS session details from temp file
aws-load() {
  local suffix="-${1:-$AWS_PROFILE}"
  local session_file="/tmp/aws-session${suffix}"
  [ -f ${session_file} ] && source ${session_file}
}

# Seconds until current aws session expires
aws-session-time() {
  echo $((3600 - $(($(date +%s) - $AWS_SESSION_TIME )) ))
}

# Loads aws profile and refreshes token if needed
# Call function with aws profile name as arguemnt
aws-apply-profile() {
  local role="${1:-$AWS_PROFILE}"
  local force="${2}"
  echo "aws-apply-profile ${role} ${force}"
  aws-load ${role}
  if [ "${force}" = "-f" ]; then 
    aws-expect ${role}
    aws-save ${role}
    return
  fi
  if [ "$(aws sts get-caller-identity 2> /dev/null )" ] && [ $(aws-session-time) -gt 300 ]; then 
    echo "Session still valid for $(aws-session-time) seconds. Use -f to force refresh"
    return
  fi
  aws-expect ${role}
  aws-load ${role}
}


# Parse credentials file for role Arn of specific profile
# Call function with aws profile name as argument
aws-extract-role-arn() {
  local profile="${1}"
  local cred_file=${2:-"$HOME/.aws/config"}
  local config=()
  local save="false"
  while read -r line; do
    if [ ! -z "$(echo ${line} | grep '\[.*\]')" ]; then
      save="false"
    fi
    if [ "${save}" = "true" ]; then
      config+=("${line}")
    fi
    if [ ! -z "$(echo ${line} | grep ${profile}] )" ]; then
      save="true"
    fi
  done < ${cred_file}
  for a in "${config[@]}"; do
    if [ ! -z "$(echo ${a} | grep 'role_arn')" ]; then
      echo ${a} | cut -d "=" -f 2 | awk '{print $1}'
    fi
  done
}

# Parse config file for mfa serial Arn of specific profile
# Call function with aws profile name as argument
aws-extract-mfa-arn() {
  local profile="${1}"
  local cred_file=${2:-"$HOME/.aws/config"}
  local config=()
  local save="false"
  while read -r line; do
    if [ ! -z "$(echo ${line} | grep '\[.*\]')" ]; then
      save="false"
    fi
    if [ "${save}" = "true" ]; then
      config+=("${line}")
    fi
    if [ ! -z "$(echo ${line} | grep ${profile}] )" ]; then
      save="true"
    fi
  done < ${cred_file}
  for a in "${config[@]}"; do
    if [ ! -z "$(echo ${a} | grep -w 'mfa_serial')" ]; then
      echo ${a} | cut -d "=" -f 2 | awk '{print $1}'
    fi
  done
}


aws-expect() {
  local profile="${1}"
  local token_code="$(aws-mfa-token ${profile})"
  local mfa="$(aws-extract-mfa-arn ${profile})"
  if [ -n "${mfa}" ];then
  echo "set timeout -1
spawn /tmp/expect_aws_token.sh
match_max 100000
expect -exact \"Enter MFA code for ${mfa}: \"
send -- \"$token_code\\r\"
expect eof" > /tmp/expect_script.exp
  chmod 777 /tmp/expect_script.exp
  echo "#!/usr/bin/env bash
source $HOME/.profile
aws-assume-role $profile
aws-save ${profile}" > /tmp/expect_aws_token.sh
  chmod 777 /tmp/expect_aws_token.sh
  expect /tmp/expect_script.exp
  else
    aws-assume-role $profile
    aws-save ${profile}
  fi
  aws-load ${profile}
}


# Load aws profile and export session variables
# aws-assume-role <profile>
aws-assume-role() {
  local profile="${1}"
  local arn="$(aws-extract-role-arn ${profile})"
  local mfa="$(aws-extract-mfa-arn ${profile})"
  local token_code="$(aws-mfa-token ${profile})"


  echo "token: ${token_code}"
  mfa="${mfa:+"--serial-number ${mfa}"}"
  #token_code="${token_code:+"--token-code '${token_code}'"}"
  if [ ! -z "${arn}" ]; then
    cmd "sts=\"\$(aws sts assume-role --role-arn ${arn} --role-session-name stanton-${profile} --profile ${profile} )\""
    if [ $? -ne 0 ]; then echo "System time incorrect?"; fi
  fi
  export AWS_SESSION_TOKEN="$(echo $sts | jq -r '.Credentials.SessionToken')"
  export AWS_SECURITY_TOKEN="$AWS_SESSION_TOKEN"
  export AWS_ACCESS_KEY_ID="$(echo $sts | jq -r '.Credentials.AccessKeyId')"
  export AWS_SECRET_ACCESS_KEY="$(echo $sts | jq -r '.Credentials.SecretAccessKey')"
  export AWS_PROFILE="${profile}"
}

# Generate MFA token and pass to awscli
# aws-mfa-token <mfa profile>
aws-mfa-token() {
  local profile="${1}"
  local token_code=""
  case "${profile}" in
    *)
      token_code="$(gauth | grep 'Prod Token' | awk '{print $4}')";;
  esac
  echo "${token_code}"
}

# Display your current AWS identity
aws-whoami() {
  local alias="$(aws iam list-account-aliases | jq -r '.AccountAliases[0]' )"
  local sts="$(aws sts get-caller-identity)"
  local user="$(echo ${sts} | jq -r '.UserId')"
  local account="$(echo ${sts} | jq -r '.Account')"
  local arn="$(echo ${sts} | jq -r '.Arn')"
  echo "You are in account: ${alias} (${account}) as ${arn}"
}


# Report RDS cluster details
# Call function with region as argument
aws-report-rds-clusters() {
  local region=${1:-us-west-2}
  aws rds describe-db-clusters --region ${region} 2> /dev/null | jq '.DBClusters[] | [ .DBClusterIdentifier, .Engine, .EngineVersion, .Status, .DBSubnetGroup ]'
}

# Create a table of all RDS cluster in an account
aws-report-all-rds-clusters() {
  aws-apply-profile
  local regions=$(aws ec2 describe-regions | jq -r '.Regions[].RegionName' )
  local json='[ "Name", "Type", "Version", "Status", "subnet" ]'
  for region in ${regions[@]}; do
    echo "region: ${region}"
    json+="$(aws-report-rds-clusters ${region})"
  done
  echo ""
  echo ${json} | jq -r '. | @tsv' | column -t -s$'\t' -n -
}

# Create a table of all EC2 instances in region
aws-report-all-rds-clusters() {
  aws-apply-profile
  local instances=$(aws ec2 describe-instances | jq -r '.Reservations[].Instances' )
  local json='[ "Name", "Type", "Version", "Status", "subnet" ]'
  for instance in ${instances[@]}; do
    echo "region: ${region}"
    json+="$(aws-report-rds-clusters ${region})"
  done
  echo ""
  echo ${json} | jq -r '. | @tsv' | column -t -s$'\t' -n -
}


# Create RDS snapshot that create Tags for all settings
# Call function with rds cluster name as arguement
aws-rds-snapshot() {
  declare -A tags=()
  local cluster_name="${1}"
  if [ -z "${cluster_name}" ]; then return 1; fi
  local cluster_details=$(aws rds describe-db-clusters --db-cluster-identifier ${cluster_name} | jq -r '.DBClusters[]')
  tags+=([params_cluster]="$(echo $cluster_details | jq -r '.DBClusterParameterGroup')")
  tags+=([DBClusterParameterGroup]="$(echo $cluster_details | jq -r '.DBClusterParameterGroup')")
  tags+=([Status]="$(echo $cluster_details | jq -r '.Status')")
  tags+=([Engine]="$(echo $cluster_details | jq -r '.Engine')")
  tags+=([EngineVersion]="$(echo $cluster_details | jq -r '.EngineVersion')")  
  tags+=([KmsKeyId]="$(echo $cluster_details | jq -r '.KmsKeyId')")
  tags+=([IAMDatabaseAuthenticationEnabled]="$(echo $cluster_details | jq -r '.IAMDatabaseAuthenticationEnabled')")
  tags+=([AutoMinorVersionUpgrade]="$(echo $cluster_details | jq -r '.AutoMinorVersionUpgrade')")
  tags+=([DBSubnetGroup]="$(echo $cluster_details | jq -r '.DBSubnetGroup')")
  tags+=([MultiAZ]="$(echo $cluster_details | jq -r '.MultiAZ')")
  tags+=([Port]="$(echo $cluster_details | jq -r '.Port')")
  tags+=([VpcSecurityGroupId]="$(echo $cluster_details | jq -r '.VpcSecurityGroups[].VpcSecurityGroupId' | sed ':a;N;$!ba;s/\n/ /g' )")
  local db_writer="$(echo $cluster_details | jq -r '.DBClusterMembers[] | select(.IsClusterWriter == true) | .DBInstanceIdentifier' )"
  local writer_details="$(aws rds describe-db-instances --db-instance-identifier ${db_writer} | jq -r '.DBInstances[]')"
  tags+=([VpcId]="$(echo $writer_details | jq -r '.DBSubnetGroup.VpcId')")
  tags+=([DBParameterGroupName]="$(echo $writer_details | jq -r '.DBParameterGroups[0].DBParameterGroupName' )")
  tags+=([PubliclyAccessible]="$(echo $writer_details | jq -r '.PubliclyAccessible' )")
  tags+=([CACertificateIdentifier]="$(echo $writer_details | jq -r '.CACertificateIdentifier' )")
  tags+=([DBInstanceClass]="$(echo $writer_details | jq -r '.DBInstanceClass' )")
  local tag_line="["

  for key in ${!tags[@]}; do 
    tag_line="${tag_line} { \"Key\": \"${key}\", \"Value\": \"${tags[$key]}\" },"
  done
  tag_line="${tag_line:0:-1} ]"

  if [[ "${engine}" =~ "aurora" ]]; then
    aws rds create-db-cluster-snapshot --db-cluster-snapshot-identifier "${cluster_name}-$(date +%s)" --db-cluster-identifier ${cluster_name} --tags "${tag_line}"
  else
    aws rds create-db-snapshot --db-snapshot-identifier ${cluster_name} --db-identifier "${cluster_name}-$(date +%s)" --tags "${tag_line}"
  fi
}

# Login to AWS ECR repo with docker
# aws-ecr-login [repo] [region]
aws-ecr-login() {
  local repo="${1:-785540879854.dkr.ecr.us-west-2.amazonaws.com}"
  local region="${2:+"--region ${2}"}"
  local token="$(aws ecr get-login-password ${region})"
  echo ${token} | docker login --username AWS --password-stdin "${repo}"
}

# Delete images from repo that match a tag
# aws-ecr-purge <registry> <tag> [repo] [region]
aws-ecr-purge() {
  local registry="${1}"
  local tag="${2}"
  local repo="${3:-785540879854.dkr.ecr.us-west-2.amazonaws.com}"
  local region="${4:+"--region ${4}"}"
  local images="$(aws ecr describe-images --repository-name ${registry} ${region} | jq -r '.imageDetails[] | select (.imageTags[]? | contains("'${tag}'") ) | .imageTags[]' | grep ${tag} | sort -u)"
  for i in ${images[@]}; do
    echo "aws ecr batch-delete-image --repository-name ${registry} --image-ids imageTag=${i} ${region}"
    aws ecr batch-delete-image --repository-name ${registry} --image-ids imageTag=${i} ${region}
  done
}

aws-ecr-repositories() {
  local region="${1:+"--region ${1}"}"
  aws ecr describe-repositories | jq -r '.repositories[] | [.repositoryName, .repositoryUri] | @tsv' | sort | column  -t -s$'\t' -n -
}

#####################
##### DMS FUNCTIONS
####################

# Start all dms tasks
aws-dms-start-tasks() {
  aws-apply-profile
  if [ "${AWS_PAGER-unset}" = unset ]; then pager="unset";fi; export AWS_PAGER=""
  for json in $(aws dms describe-replication-tasks | jq -r '.ReplicationTasks[] | select(.Status != "running") |  [ .Status, .ReplicationTaskArn ] | @base64' ); do 
    local status="$(echo $json | base64 --decode | jq -r .[0])"
    local arn="$(echo $json | base64 --decode | jq -r .[1])"
    case $status in
      stopped)
        aws dms start-replication-task --start-replication-task-type start-replication --replication-task-arn ${arn} > /dev/null &
        ;;
      failed)
        aws dms start-replication-task --start-replication-task-type resume-processing --replication-task-arn ${arn} > /dev/null &
        ;;
      *)
        aws dms start-replication-task --start-replication-task-type reload-target --replication-task-arn ${arn} > /dev/null &
        ;;
    esac
  done
  if [ "${pager}" = unset ]; then unset AWS_PAGER ;fi
}

# Delete all current assessment reports for DMS tasks
aws-dms-delete-reports() {
  aws-apply-profile
  local bucket_name="${1}"
  if [ "${AWS_PAGER-unset}" = unset ]; then pager="unset";fi;export AWS_PAGER=""
  for ARN in $(aws dms describe-replication-task-assessment-runs | jq -r '.ReplicationTaskAssessmentRuns[].ReplicationTaskAssessmentRunArn'); do 
    aws dms delete-replication-task-assessment-run --replication-task-assessment-run-arn $ARN &
    if [ ! -z "${bucket_name}" ]; then
      aws s3 rm s3://${bucket_name}/dms/$(echo $ARN | rev | cut -d":" -f1 | rev)
    fi
  done  
  if [ "${pager}" = unset ]; then unset AWS_PAGER ;fi
}

# Delete all current DMS endpoints, both source and target
aws-dms-delete-endpoints() {
  aws-apply-profile
  if [ "${AWS_PAGER-unset}" = unset ]; then pager="unset";fi;export AWS_PAGER=""
  for ARN in $(aws dms describe-endpoints | jq -r '.Endpoints[].EndpointArn'); do 
    aws dms delete-endpoint --endpoint-arn $ARN > /dev/null &
  done  
  if [ "${pager}" = unset ]; then unset AWS_PAGER ;fi
}

# Delete all configured DMS tasks
aws-dms-delete-tasks() {
  aws-apply-profile
  if [ "${AWS_PAGER-unset}" = unset ]; then pager="unset";fi;export AWS_PAGER=""
  for ARN in $(aws dms describe-replication-tasks | jq -r '.ReplicationTasks[].ReplicationTaskArn'); do 
    ( aws dms stop-replication-task --replication-task-arn $ARN 2>&1 /dev/null 
      while [ "$(aws dms describe-replication-tasks --filters Name=replication-task-arn,Values=$ARN | jq -r '.ReplicationTasks[].Status')" != "stopped" ]; do
        sleep 10
      done
      aws dms delete-replication-task --replication-task-arn $ARN 2>&1 /dev/null ) &
  done  
  if [ "${pager}" = unset ]; then unset AWS_PAGER ;fi
}

######### EC2 Functions

# Filter EC2 instances by name
# aws-ec2-name some-name*
aws-ec2-name() {
  local name_filter="${1}"
  if [ "${AWS_PAGER-unset}" = unset ]; then pager="unset";fi;export AWS_PAGER=""
  json=$(aws ec2 describe-instances --filters Name=tag:Name,Values=${name_filter})
  if [ "${pager}" = unset ]; then unset AWS_PAGER ;fi
  echo "${json}"
}

# List VPC details by region
# aws-list-vpcs region
aws-list-vpcs() {
  local region="${1:+--region ${1}}"
  local format="${2:-table}"
  local vpcs vpc_object vpc
  local vpc_json="$(aws ec2 describe-vpcs ${region})"
  while read -r vpc; do
    if [[ -n "$(echo ${vpc} | jq '.Tags[]' 2> /dev/null)" ]]; then 
      vpc_object=$(echo [${vpc}] | jq 'map({VpcId,CidrBlock,Name: (.Tags[]|select(.Key=="Name")|.Value)})')
    else
      echo "No Tags" 
      vpc_object=$(echo [${vpc}] | jq 'map({VpcId,CidrBlock})')
    fi
    vpcs="$(echo ${vpcs} | jq ". + ${vpc_object}")"
    vpcs="${vpcs:-$vpc_object}"
  done <<< "$(echo "${vpc_json}" | jq -c '.Vpcs[]')"
  if [[ "${format}" == "table" ]]; then 
    echo ${vpcs} | jq -r '.[]| [.VpcId, .CidrBlock, .Name] | @tsv' | column -t -s$'\t'
  else
    echo "${vpcs}"
  fi
}

# List Subnets details by region
# aws-list-subnets region
aws-list-subnets() {
  local region="${1:+--region ${1}}"
  local subnets vpc_id vpc2 subnet_json subnet_table
  local json="$(aws-list-vpcs "${1}" "json")"
  while read -r vpc; do
    vpc_id=$(echo "${vpc}" | jq -r '.VpcId')
    vpc2=$(echo "${vpc}" | jq -r '. | .["VpcName"] = .Name | .["VpcCidrBlock"] = .CidrBlock | del(.CidrBlock, .Name)')
    subnet_json=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=${vpc_id} ${region})
    if [ "$(echo ${subnet_json} | jq '.Subnets[].Tags[]' 2> /dev/null)" ]; then 
      subnets="$(echo ${subnet_json} | jq "[.[]|map({SubnetId,AvailabilityZone,CidrBlock,Name: (.Tags[]|select(.Key==\"Name\")|.Value)})| .[] + ${vpc2}]")"
    else
      subnets="$(echo ${subnet_json} | jq "[.[]|map({SubnetId,AvailabilityZone,CidrBlock})| .[] + ${vpc2}]")"
    fi
    subnet_table="$(echo ${subnet_table} | jq ". + ${subnets}")"
    subnet_table="${subnet_table:-$subnets}"
  done <<< "$(echo "${json}" | jq -c '.[]' )"
    echo "${subnet_table}" | jq -r '.[] | [.VpcId, .VpcCidrBlock, .VpcName, .SubnetId, .AvailabilityZone, .CidrBlock, .Name] | @tsv' | column -t -s$'\t'
}

# List available secrets per region
# aws-list-secrets [region]
aws-list-secrets() {
  local region="${1:+--region ${1}}"
  aws secretsmanager list-secrets ${region} | jq -r '.SecretList[].Name' 
}

# List available secrets per region
# aws-get-secret <secret_name> [region]
aws-get-secret() {
  local secret="${1}"
  local region="${2:+--region ${2}}"
  aws secretsmanager get-secret-value --secret-id ${secret} ${region} | jq -r '.SecretString' 
}

aws-check-binary() {
  if [ -z "$(command -v aws)" ]; then
    echo "install awscli"
    return 1
  fi
  local version="$( aws --version | awk -F"[ \t/]+" '{print $2}')"
  local latest="$(curl -s https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst | head -n 5 | grep '^[0-9]')"  
  if [ "${version}" != "${latest}" ]; then
    echo "New awscli version available. Current: ${version}, Latest: ${latest}"
  fi
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi