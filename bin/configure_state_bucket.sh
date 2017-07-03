#!/usr/bin/env bash

set -eu

if [ $# -ne 4 ] ; then
  cat >&2 <<EOM
Usage: $0 <bucket_name> <state_file_path> <terraform_dir> <region>

Configure terraform to store state in s3.

The <terraform_dir> should contain terraform files, (e.g. main.tf).

WARNING: this script will \`rm -rf' any .terraform directory present under the
terraform_dir, so be careful about where you run this from.
EOM
exit 1
fi

BUCKET=$1
STATE=$2
TF_DIR=$3
REGION=$4

run() {
    echo >&2 "+ $*"
    "$@"
}
terraform() {
  echo >&2 "+ terraform $*"
  command terraform "$@"
}
aws() {
  echo >&2 "+ aws $*"
  command aws "$@"
}

echo "Using state file $STATE"

echo >&2 "+ aws s3api head-bucket --bucket $BUCKET"
output="$(command aws s3api head-bucket --bucket "$BUCKET" 2>&1)" \
    && ret=$? || ret=$?

echo >&2 "$output"
if grep -F "Not Found" <<< "$output" >/dev/null; then
    echo "Bucket $BUCKET does not exist, creating..."
    echo "Creating an s3 bucket for terraform state"

    # Do not create the bucket if it contains underscores. See
    # https://github.com/18F/identity-private/issues/1835
    if [[ $BUCKET = *_* ]]; then
        echo "Can't create $BUCKET because it contains underscores"
        exit 1
    else
        aws s3 mb "s3://$BUCKET"

        echo "Enabling versioning on the s3 bucket"
        aws s3api put-bucket-versioning \
          --bucket "$BUCKET" \
          --versioning-configuration Status=Enabled
    fi
elif [ "$ret" -ne 0 ]; then
    exit "$ret"
fi

echo "Using terraform remote state server"
echo "Deleting ${TF_DIR}/.terraform"
cd "${TF_DIR}"
run rm -rfv .terraform

# https://github.com/hashicorp/terraform/issues/12762
case "$(CHECKPOINT_DISABLE=1 terraform --version)" in
  *v0.9.*)
    terraform init \
      -backend-config="bucket=${BUCKET}" \
      -backend-config="key=${STATE}" \
      -backend-config="region=${REGION}"
    ;;
  *v0.8.*)
    terraform remote config -backend=s3 \
      -backend-config="bucket=${BUCKET}" \
      -backend-config="key=${STATE}" \
      -backend-config="region=${REGION}" \
      -state="${STATE}"
    ;;
  *)
    echo "ERROR: Unsupported terraform version"
    exit 1
    ;;
esac
