#!/bin/bash

export AWS_PROFILE='default'

mkdir -p iam/policies

POLICIES=$(aws iam list-policies --scope Local --query "Policies[*].{name: PolicyName, version: DefaultVersionId, arn: Arn}")

echo $POLICIES | jq -c '.[]' | \
while read policy; do
    POLICY_NAME=$(echo $policy | jq -r '.name')
    POLICY_ARN=$(echo $policy | jq -r '.arn')
    POLICY_VERSION=$(echo $policy | jq -r '.version')

    POLICY_DOCUMENT=$(aws iam get-policy-version --policy-arn $POLICY_ARN --version-id $POLICY_VERSION --query "PolicyVersion.Document")
    echo $POLICY_DOCUMENT | jq . > iam/policies/$POLICY_NAME.json
done


mkdir -p iam/roles
ROLES=$(aws iam list-roles --query "Roles[*].{name: RoleName, path: Path, sts: AssumeRolePolicyDocument}")

echo $ROLES | jq -cr '.[]' | \
while read role; do
    ROLE_NAME=$(echo $role | jq -r '.name')
    mkdir -p iam/roles/$ROLE_NAME

    echo $role | jq -r '{path: .path, sts: .sts}' > iam/roles/$ROLE_NAME/$ROLE_NAME.json

    mkdir -p iam/roles/$ROLE_NAME/policies
    aws iam list-attached-role-policies --role-name $ROLE_NAME --query "AttachedPolicies[].PolicyArn" | sed -E 's#arn:aws:iam::[0-9]{10,}:policy/##g' | jq '. | sort' > iam/roles/$ROLE_NAME/policies/managed.json

    mkdir -p iam/roles/$ROLE_NAME/policies/inline
    aws iam list-role-policies --role-name $ROLE_NAME --query "PolicyNames[]" | jq -cr '.[]' | \
    while read inline_policy; do
        if [[ -z $inline_policy ]]; then
            continue
        fi
        aws iam get-role-policy --role-name $ROLE_NAME --policy-name "$inline_policy" --query "PolicyDocument" > iam/roles/$ROLE_NAME/policies/inline/$inline_policy.json
    done
done

mkdir -p iam/instance-profiles

INSTANCE_PROFILES=$(aws iam list-instance-profiles --query "InstanceProfiles[].{name: InstanceProfileName, out: {path:Path, roles: Roles[].RoleName}}")
echo $INSTANCE_PROFILES | jq -cr '.[]' | \
while read profile; do
    PROFILE_NAME=$(echo $profile | jq -r '.name')
    echo $profile | jq -r '.out' > iam/instance-profiles/$PROFILE_NAME.json
done


mkdir -p iam/groups
IAMGROUPS=$(aws iam list-groups --query "Groups[].{name: GroupName, path: Path}")

echo $IAMGROUPS | jq -rc '.[]' | \
while read iam_group; do
    GROUP_NAME=$(echo $iam_group | jq -r '.name')
    mkdir -p iam/groups/$GROUP_NAME
    echo $iam_group | jq -r '{path: .path}' > iam/groups/$GROUP_NAME/$GROUP_NAME.json

    mkdir -p iam/groups/$GROUP_NAME/policies
    aws iam list-attached-group-policies --group-name $GROUP_NAME --query "AttachedPolicies[].PolicyArn" | sed -E 's#arn:aws:iam::[0-9]{10,}:policy/##g' | jq '. | sort' > iam/groups/$GROUP_NAME/policies/managed.json

    mkdir -p iam/groups/$GROUP_NAME/policies/inline
    aws iam list-group-policies --group-name $GROUP_NAME --query "PolicyNames[]" | jq -cr '.[]' | \
    while read inline_policy; do
        if [[ -z $inline_policy ]]; then
            continue
        fi
        aws iam get-group-policy --group-name $GROUP_NAME --policy-name "$inline_policy" --query "PolicyDocument" > iam/groups/$GROUP_NAME/policies/inline/$inline_policy.json
    done
done
