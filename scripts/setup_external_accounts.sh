#!/bin/bash
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file is a mostly common setup file to ensure all workload identity
# federation integration tests are set up in a consistent fashion across the
# languages in our various client libraries. It assumes that the current user
# has the relevant permissions to run each of the commands listed.

# This script needs to be run once. It will do the following:
# 1. Create a random workload identity pool.
# 2. Create a random OIDC provider in that pool which uses the
#    accounts.google.com as the issuer and the default STS audience as the
#    allowed audience. This audience will be validated on STS token exchange.
# 3. Enable OIDC tokens generated by the current service account to impersonate
#    the service account. (Identified by the OIDC token sub field which is the
#    service account client ID).
# 4. Create a random AWS provider in that pool which uses the provided AWS
#    account ID.
# 5. Enable AWS provider to impersonate the service account. (Principal is
#    identified by the AWS role name).
# 6. Print out the STS audience fields associated with the created providers
#    after the setup completes successfully so that they can be used in the
#    tests. These will be copied and used as the global _AUDIENCE_OIDC and
#    _AUDIENCE_AWS constants in system_tests/system_tests_sync/test_external_accounts.py.
#
# It is safe to run the setup script again. A new pool is created and new
# audiences are printed. If run multiple times, it is advisable to delete
# unused pools. Note that deleted pools are soft deleted and may remain for
# a while before they are completely deleted. The old pool ID cannot be used
# in the meantime.
#
# For AWS tests, an AWS developer account is needed.
# The following AWS prerequisite setup is needed.
# 1. An OIDC Google identity provider needs to be created with the following:
#    issuer: accounts.google.com
#    audience: Use the client_id of the service account.
# 2. A role for OIDC web identity federation is needed with the created Google
#    provider as a trusted entity:
#    "accounts.google.com:aud": "$CLIENT_ID"
# The steps are documented at:
# https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html

suffix=""

function generate_random_string () {
  local valid_chars=abcdefghijklmnopqrstuvwxyz0123456789
  for i in {1..8} ; do
    suffix+="${valid_chars:RANDOM%${#valid_chars}:1}"
    done
}

generate_random_string

pool_id="pool-"$suffix
oidc_provider_id="oidc-"$suffix
aws_provider_id="aws-"$suffix

# TODO: Fill in.
project_id="stellar-day-254222"
project_number="79992041559"
aws_account_id="077071391996"
aws_role_name="ci-python-test"
service_account_email="kokoro@stellar-day-254222.iam.gserviceaccount.com"
sub="104692443208068386138"

oidc_aud="//iam.googleapis.com/projects/$project_number/locations/global/workloadIdentityPools/$pool_id/providers/$oidc_provider_id"
aws_aud="//iam.googleapis.com/projects/$project_number/locations/global/workloadIdentityPools/$pool_id/providers/$aws_provider_id"

gcloud config set project $project_id

# Create the Workload Identity Pool.
gcloud beta iam workload-identity-pools create $pool_id \
    --location="global" \
    --description="Test pool" \
    --display-name="Test pool for Python"

# Create the OIDC Provider.
gcloud beta iam workload-identity-pools providers create-oidc $oidc_provider_id \
    --workload-identity-pool=$pool_id \
    --issuer-uri="https://accounts.google.com" \
    --location="global" \
    --attribute-mapping="google.subject=assertion.sub"

# Create the AWS Provider.
gcloud beta iam workload-identity-pools providers create-aws $aws_provider_id \
    --workload-identity-pool=$pool_id \
    --account-id=$aws_account_id \
    --location="global"

# Give permission to impersonate the service account.
gcloud iam service-accounts add-iam-policy-binding $service_account_email \
--role roles/iam.workloadIdentityUser \
--member "principal://iam.googleapis.com/projects/$project_number/locations/global/workloadIdentityPools/$pool_id/subject/$sub"

gcloud iam service-accounts add-iam-policy-binding $service_account_email \
  --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/$project_number/locations/global/workloadIdentityPools/$pool_id/attribute.aws_role/arn:aws:sts::$aws_account_id:assumed-role/$aws_role_name"

echo "OIDC audience: "$oidc_aud
echo "AWS audience: "$aws_aud
