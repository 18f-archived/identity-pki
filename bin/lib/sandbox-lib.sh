#!/bin/bash

# ensure that all required TF_ENV files (Chef/tfvars/etc.) exist
verify_env_files() {
  for FILE in "${GIT_DIR}/kitchen/environments/${TF_ENV}.json" \
              "${PRIVATE_REPO}/vars/${TF_ENV}.tfvars" \
              "${PRIVATE_REPO}/chef/environments/${TF_ENV}.json" \
              "${PRIVATE_REPO}/env/${TF_ENV}.sh" ; do
    FILENAME=$(echo ${FILE} | awk -F/ '{print $NF}')
    FILEPATH=$(echo ${FILE} | awk -F/ '{$NF=""; print $0}')
    [[ -f "${FILE}" ]] || raise "${FILENAME} not found at ${FILEPATH}"
  done
  echo_cyan "Environment config files exist and are valid."
}

# verify that passed-in TF_ENV / GSA_USERNAME is valid and that environment
# is not protected/staging/prod
verify_sandbox_env() {
  TF_ENV=${1:-$(echo ${GSA_USERNAME})}
  if [[ -z ${TF_ENV} ]] ; then
    raise "GSA_USERNAME not set; verify and try again"
  elif [[ $(grep -w 'STRICT_ENVIRONMENT' ${PRIVATE_REPO}/env/${TF_ENV}.sh) ]] ; then
    raise "Cannot run this script against protected environment ${TF_ENV}"
  elif [[ "${TF_ENV}" =~ ^staging|prod$ ]] ; then
    raise "Cannot be run against the login-prod account!"
  fi
  echo_cyan "Using '${TF_ENV}' environment."
  verify_env_files
}

# run verify functions above, confirm correct AV_PROFILE, and verify the
# APP_DIR, AWS account number, and region, before continuing the main script
initialize() {
  local RUN_AS_TERRAFORM=${1}
  local ACCOUNT=${3:-'sandbox'}
  shift 1
  echo
  echo_green "Initializing..."
  verify_root_repo
  verify_private_repo
  verify_sandbox_env ${1:-}
  if [[ ${RUN_AS_TERRAFORM} == "true" ]] ; then
    get_iam 'app' "${ACCOUNT}" 'Terraform'
    if [[ ! -z ${AWS_VAULT:-} ]] && [[ ${AWS_VAULT} != ${AV_PROFILE} ]] ; then
      raise "Must use ${AV_PROFILE} profile (detected: ${AWS_VAULT})"
    fi
  fi

  APP_DIR="${GIT_DIR}/terraform/app"
  AWS_ACCT_NUM=$(ave aws sts get-caller-identity | jq -r '.Account')
}

# disable prevent_destroy and deletion_protection configs for Aurora databases
# by changing the strings/comments in module's main.tf file + creating .bak version
remove_db_protection_in_state() {
  local FILE="$(git rev-parse --show-toplevel)/terraform/modules/rds_aurora/main.tf"
  cp "${FILE}" "${FILE}.bak"
  for TASK in prevent_destroy deletion_protection ; do
    sed -i '' -E "s/(${TASK} = )true/\1false/g" "${FILE}"
  done
  sed -i '' -E 's/#(skip_final_snapshot = true)/\1/g' "${FILE}"
}

# if .bak version of rds_aurora/main.tf file exists, revert back to the original
replace_db_files() {
  local FILE="$(git rev-parse --show-toplevel)/terraform/modules/rds_aurora/main.tf"
  if [[ -f "${FILE}.bak" ]] ; then
    mv ${FILE}.bak ${FILE}
  fi
}
