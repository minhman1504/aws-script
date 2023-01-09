#!/bin/bash

# Init Step: checking parameters
STAGE_NAME=$STAGE_NAME
PROJECT_NAME=$PROJECT_NAME

if [ $STAGE_NAME eq 'stg' ]
then
    ENVIRONMENT="Staging"
elif [ $STAGE_NAME eq 'test' ]
then
    ENVIRONMENT="Test"
else
    ENVIRONMENT="Development"
fi

echo "StageName: $STAGE_NAME"
echo "ProjectName: $PROJECT_NAME" 
echo "Environment: $ENVIRONMENT" 

# Step 01: Generate KMS Key Pair
aws kms ge-key-pair \
    --key-id "$STAGE_NAME-key-id" \
    --key-pair-spec RSA_2048 > kms-gen-key-respnerate-dataonse.json
ENCODED_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----$(grep -o '"PublicKey": "[^"]*' kms-gen-key-response.json | grep -o '[^"]*$')-----END PUBLIC KEY-----"
DECODED_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----$(grep -o '"PrivateKeyPlaintext": "[^"]*' kms-gen-key-response.json | grep -o '[^"]*$' | base64 -d)-----END PRIVATE KEY-----"
echo "EncodedPublicKey: $ENCODED_PUBLIC_KEY"
echo "EncodedPrivateKey: $DECODED_PRIVATE_KEY"

# Step 02: Create CloudFront PublicKey
aws cloudfront create-public-key \ 
    --public-key-config "CallerReference=$STAGE_NAME-CallerReference,Name=$STAGE_NAME-CF-PublicKey,EncodedKey=$ENCODED_PUBLIC_KEY,Comment=$STAGE_NAME-CF-Comment" > cf-create-publickey-response.json
PUBLIC_KEY_ID="$(grep -o '"Id": "[^"]*' cf-create-publickey-response.json | grep -o '[^"]*$')"
echo "PublicKeyId: $PUBLIC_KEY_ID"

# Step 03: Add Public Key to CloudFront Key Group
aws cloudfront update-key-group \
    --key-group-config "Name=$STAGE_NAME-CF-Key,Items=$PUBLIC_KEY_ID,Comment=$STAGE_NAME-CF-KeyGroup-Comment" \
    --id "$PROJECT_NAME-$STAGE_NAME-infra-keygroup"

# Step 04: Create SSM Parameter
aws ssm put-parameter \
    --name "$STAGE_NAME-CFPublicKeyId" \
    --value "$PUBLIC_KEY_ID" \ 
    --type String \
    --tags "[{'Key':'Project','Value': ${PROJECT_NAME^^}},{'Key':'Environment','Value': $ENVIRONMENT}, {'Key':'CostCenter','Value': 'Terumo'}, {'Key':'ProjectOwner','Value': 'Terumo'}]"
    --overwrite

# Step 05: Create secret
aws secretsmanager create-secret \
    --name "$STAGE_NAME-CFPrivateKey" \
    --secret-string "$DECODED_PRIVATE_KEY"
    --force-overwrite-replica-secret

# Final Step: Cleanup 
rm --force cf-create-publickey-response.json kms-gen-key-response.json