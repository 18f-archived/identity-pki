#!/bin/bash

# Uses Gitlab image SHAs from .gitlab-ci.yml to docker tag images and docker push them to other accounts
# Should be run against tooling-sandbox

debug=0

jq="jq --exit-status --raw-output"

rm -f .gitlab_env_runner_allowed_images
temporary_file=$(mktemp .gitlab_env_runner_allowed_images)

aws_account_info_json=$(aws sts get-caller-identity)

if [[ $debug -ne 0 || ! $debug ]]; then
    echo "echo $aws_account_info_json" 1>&2
fi

tooling_prod_account_number=217680906704
aws_account_number=$(echo "$aws_account_info_json" | $jq .Account)
rv="$?"
if [[ $rv -ne 0 || ! $aws_account_number ]]; then
    echo "$pkg: failed to parse output for aws_account_number" 1>&2
    exit 1
fi

aws_current_region=$(aws configure get region)

if [[ $debug -ne 0 || ! $debug ]]; then
    echo "echo $aws_current_region" 1>&2
fi

rv="$?"
if [[ $rv -ne 0 || ! $aws_current_region ]]; then
    echo "$pkg: failed to parse output for aws_current_region" 1>&2
    exit 1
fi

deploy_image_digest=$(sed -n -e '/^[ ]*DEPLOY_IMAGE_DIGEST/p' ../identity-devops/.gitlab-ci.yml | cut -d'"' -f2)
rv="$?"
if [[ $rv -ne 0 || ! $deploy_image_digest ]]; then
    echo "$pkg: failed to parse output for deploy_image_digest" 1>&2
    exit 1
fi

test_image_digest=$(sed -n -e '/^[ ]*TEST_IMAGE_DIGEST/p' ../identity-devops/.gitlab-ci.yml | cut -d'"' -f2)
rv="$?"
if [[ $rv -ne 0 || ! $test_image_digest ]]; then
    echo "$pkg: failed to parse output for test_image_digest" 1>&2
    exit 1
fi

gitdeploy_image_digest=$(sed -n -e '/^[ ]*GITDEPLOY_IMAGE_DIGEST/p' ../identity-devops/.gitlab-ci.yml | cut -d'"' -f2)
rv="$?"
if [[ $rv -ne 0 || ! $gitdeploy_image_digest ]]; then
    echo "$pkg: failed to parse output for gitdeploy_image_digest" 1>&2
    exit 1
fi

gittest_image_digest=$(sed -n -e '/^[ ]*GITTEST_IMAGE_DIGEST/p' ../identity-devops/.gitlab-ci.yml | cut -d'"' -f2)
rv="$?"
if [[ $rv -ne 0 || ! $gittest_image_digest ]]; then
    echo "$pkg: failed to parse output for gittest_image_digest" 1>&2
    exit 1
fi

stop_image_digest=$(sed -n -e '/^[ ]*STOP_IMAGE_DIGEST/p' ../identity-devops/.gitlab-ci.yml | cut -d'"' -f2)
rv="$?"
if [[ $rv -ne 0 || ! $stop_image_digest ]]; then
    echo "$pkg: failed to parse output for stop_image_digest" 1>&2
    exit 1
fi

aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${aws_account_number}.dkr.ecr.us-west-2.amazonaws.com

if [[ $aws_account_number != $tooling_prod_account_number ]]; then
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_deploy@${deploy_image_digest} ${aws_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_deploy/blessed@${deploy_image_digest}
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/gitlab_deploy@${gitdeploy_image_digest} ${aws_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/gitlab_deploy/blessed@${gitdeploy_image_digest}
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/gitlab_test@${gittest_image_digest} ${aws_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/gitlab_test/blessed@${gittest_image_digest}
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_stop@${stop_image_digest} ${aws_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_stop/blessed@${stop_image_digest}
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_test@${test_image_digest} ${aws_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_test/blessed@${test_image_digest}
else
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_deploy@${deploy_image_digest} ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_deploy/blessed@${deploy_image_digest}
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/gitlab_deploy@${gitdeploy_image_digest} ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/gitlab_deploy/blessed@${gitdeploy_image_digest}
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/gitlab_test@${gittest_image_digest} ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/gitlab_test/blessed@${gittest_image_digest}
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_stop@${stop_image_digest} ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_stop/blessed@${stop_image_digest}
    crane copy ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_test@${test_image_digest} ${tooling_prod_account_number}.dkr.ecr.us-west-2.amazonaws.com/cd/env_test/blessed@${test_image_digest}
fi