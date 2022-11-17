#!/bin/bash
curl http://checkip.amazonaws.com

export CUSTOMERALIAS=$(aws ec2 describe-tags --filters --region us-east-1 "Name=key,Values=CustomerAlias" "Name=resource-id,Values=$(curl -s 169.254.169.254/latest/meta-data/instance-id)" | jq -r '.[] | .[0].Value ')
export AWSACCOUNTID=$(aws ec2 describe-tags --filters --region us-east-1 "Name=key,Values=AwsAccountId" "Name=resource-id,Values=$(curl -s 169.254.169.254/latest/meta-data/instance-id)" | jq -r '.[] | .[0].Value ')

if [ -z "$AWSACCOUNTID" ]
then
  echo 'Account Id is present, continuing here...'
  export ROLEARN=$(aws ssm get-parameter --name=$CUSTOMERALIAS-$AWSACCOUNTID-Cloud-Scanners-Rolearn --region us-east-1 --with-decryption | jq -r '.Parameter | .Value')
  export EXTERNALID=$(aws ssm get-parameter --name=$CUSTOMERALIAS-$AWSACCOUNTID-Cloud-Scanners-Externalid --region us-east-1 --with-decryption  | jq -r '.Parameter | .Value')
else
  echo 'Account Id NOT supplied, continuing with existing root account role...'
  export ROLEARN=$(aws ssm get-parameter --name=$CUSTOMERALIAS-Cloud-Scanners-Rolearn --region us-east-1 --with-decryption | jq -r '.Parameter | .Value')
  export EXTERNALID=$(aws ssm get-parameter --name=$CUSTOMERALIAS-Cloud-Scanners-Externalid --region us-east-1 --with-decryption | jq -r '.Parameter | .Value')
fi

echo 'CUSTOMER:'$CUSTOMERALIAS
echo 'ROLE:'$ROLEARN

echo  'Assuming Role with: '${CUSTOMERALIAS} ${ROLEARN} ${EXTERNALID}

export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
$(aws sts assume-role \
--role-arn $ROLEARN \
--external-id $EXTERNALID \
--role-session-name=Securily-CloudSploit-Session \
--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
--output text))

eval $(aws sts get-caller-identity \
--query 'join(``, [`export `, `ACCOUNT_ID=`, Account, ` ; export `, `USER_ID=`, UserId])' \
--output text)

echo  'Assuming Role with: '${ACCOUNT_ID} ${USER_ID}

{
echo '// CloudSploit config file'
echo ''
echo 'module.exports = {'
echo '    credentials: {'
echo '        aws: {'
echo '            access_key: '\"$AWS_ACCESS_KEY_ID\"','
echo '            secret_access_key: '\"$AWS_SECRET_ACCESS_KEY\"','
echo '            session_token: '\"$AWS_SESSION_TOKEN\"''
echo '        }'
echo '    }'
echo '};'
} > /home/ec2-user/cloudsploit/config.js

sleep 10s

chown ec2-user:ec2-user /home/ec2-user/cloudsploit/config.js

chmod 755 /home/ec2-user/cloudsploit/config.js

sudo su - ec2-user -s /bin/bash -c 'rm -r /home/ec2-user/cloudsploit/cloudsploit*.json'
sudo su - ec2-user -s /bin/bash -c 'rm -r /home/ec2-user/cloudsploit/cloudsploit*.csv'

sudo su - ec2-user -s /bin/bash -c '/home/ec2-user/cloudsploit/index.js --config=./config.js --json=/home/ec2-user/cloudsploit/cloudsploit.json --csv=/home/ec2-user/cloudsploit/cloudsploit.csv --console text'

sleep 10s

sudo su - ec2-user -s /bin/bash -c "cat /home/ec2-user/cloudsploit/cloudsploit.json | jq -c '.[] | select( .status == \"FAIL\" )' > /home/ec2-user/cloudsploit/cloudsploit_fail_raw.json"
sudo su - ec2-user -s /bin/bash -c "cat /home/ec2-user/cloudsploit/cloudsploit_fail_raw.json| jq --slurp '[.[]]' > /home/ec2-user/cloudsploit/cloudsploit_fail.json"

sudo su - ec2-user -s /bin/bash -c "jq 'group_by (.status)[] | {status: .[0].status, length: length}' /home/ec2-user/cloudsploit/cloudsploit.json > /home/ec2-user/cloudsploit/cloudsploit_status_counter.json"
sudo su - ec2-user -s /bin/bash -c "jq 'group_by (.category)[] | {category: .[0].category, length: length}' /home/ec2-user/cloudsploit/cloudsploit_fail.json > /home/ec2-user/cloudsploit/cloudsploit_category_counter.json"
sudo su - ec2-user -s /bin/bash -c "jq 'group_by (.plugin)[] | {test: .[0].plugin, length: length}' /home/ec2-user/cloudsploit/cloudsploit_fail.json > /home/ec2-user/cloudsploit/cloudsploit_test_counter.json"
sudo su - ec2-user -s /bin/bash -c "jq 'group_by (.region)[] | {region: .[0].region, length: length}' /home/ec2-user/cloudsploit/cloudsploit_fail.json > /home/ec2-user/cloudsploit/cloudsploit_region_counter.json"
sudo su - ec2-user -s /bin/bash -c "jq 'group_by (.resource)[] | {resource: .[0].resource, length: length}' /home/ec2-user/cloudsploit/cloudsploit_fail.json > /home/ec2-user/cloudsploit/cloudsploit_resource_counter.json"

sudo su - ec2-user -s /bin/bash -c "cat /home/ec2-user/cloudsploit/cloudsploit_status_counter.json| jq --slurp '[.[]]' > /home/ec2-user/cloudsploit/cloudsploit_summary.json"
sudo su - ec2-user -s /bin/bash -c "cat /home/ec2-user/cloudsploit/cloudsploit_category_counter.json| jq --slurp '[.[]]' > /home/ec2-user/cloudsploit/cloudsploit_category_summary.json"
sudo su - ec2-user -s /bin/bash -c "cat /home/ec2-user/cloudsploit/cloudsploit_test_counter.json| jq --slurp '[.[]]' > /home/ec2-user/cloudsploit/cloudsploit_test_summary.json"
sudo su - ec2-user -s /bin/bash -c "cat /home/ec2-user/cloudsploit/cloudsploit_region_counter.json| jq --slurp '[.[]]' > /home/ec2-user/cloudsploit/cloudsploit_region_summary.json"
sudo su - ec2-user -s /bin/bash -c "cat /home/ec2-user/cloudsploit/cloudsploit_resource_counter.json| jq --slurp '[.[]]' > /home/ec2-user/cloudsploit/cloudsploit_resource_summary.json"

sudo su - ec2-user -s /bin/bash -c "aws s3 cp /home/ec2-user/cloudsploit/cloudsploit_summary.json s3://"${CUSTOMERALIAS}"-scans-results/"${ACCOUNT_ID}"/cloudsploit/"
sudo su - ec2-user -s /bin/bash -c "aws s3 cp /home/ec2-user/cloudsploit/cloudsploit_category_summary.json s3://"${CUSTOMERALIAS}"-scans-results/"${ACCOUNT_ID}"/cloudsploit/"
sudo su - ec2-user -s /bin/bash -c "aws s3 cp /home/ec2-user/cloudsploit/cloudsploit_test_summary.json s3://"${CUSTOMERALIAS}"-scans-results/"${ACCOUNT_ID}"/cloudsploit/"
sudo su - ec2-user -s /bin/bash -c "aws s3 cp /home/ec2-user/cloudsploit/cloudsploit_region_summary.json s3://"${CUSTOMERALIAS}"-scans-results/"${ACCOUNT_ID}"/cloudsploit/"
sudo su - ec2-user -s /bin/bash -c "aws s3 cp /home/ec2-user/cloudsploit/cloudsploit_resource_summary.json s3://"${CUSTOMERALIAS}"-scans-results/"${ACCOUNT_ID}"/cloudsploit/"
sudo su - ec2-user -s /bin/bash -c "aws s3 cp /home/ec2-user/cloudsploit/cloudsploit.json s3://"${CUSTOMERALIAS}"-scans-results/"${ACCOUNT_ID}"/cloudsploit/"
sudo su - ec2-user -s /bin/bash -c "aws s3 cp /home/ec2-user/cloudsploit/cloudsploit.csv s3://"${CUSTOMERALIAS}"-scans-results/"${ACCOUNT_ID}"/cloudsploit/"

exit