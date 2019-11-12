# The following example will allow you to register/update your AWS Account credentials with the Flexera Cloud Management Platform

# Cloud Href Reference: https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html
# API Docs: https://reference.rightscale.com/api1.5/resources/ResourceCloudAccounts.html
# Refresh Token: https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps
# Using IAM to connect CMP: https://docs.rightscale.com/faq/How_do_I_use_Amazon_IAM_with_RightScale.html

$accountEndpoint = "<YOUR_ACCOUNT_ENDPOINT>" # Cloud Management Endpoints: https://docs.rightscale.com/api/general_usage.html#endpoints
$accountId = "<YOUR_ACCOUNT_NUMBER>" # Your CMP Account ID
$refreshToken = "<YOUR_REFRESH_TOKEN>" # Your Refresh Token https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps

$accountNumber = "<YOUR_AWS_ACCOUNT_ID>" # AWS Account ID
$accessKeyId = "<YOUR_AWS_IAM_USER_ACCESS_KEY_ID>" # Access Key ID for IAM User
$secretAccessKey = "<YOUR_AWS_IAM_USER_SECRET_ACCESS_KEY>" # Secret Access Key for IAM User

Add-Type -AssemblyName System.Web
$accountNumberEncoded = [System.Web.HttpUtility]::UrlEncode($accountNumber)
$accessKeyIdEncoded = [System.Web.HttpUtility]::UrlEncode($accessKeyId)
$secretAccessKeyEncoded = [System.Web.HttpUtility]::UrlEncode($secretAccessKey)

# AWS Cloud Href Reference: https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html#supported-clouds-and-parameters-aws
$cloudHrefs = @(
    "/api/clouds/1",  # AWS US-East
    "/api/clouds/2",  # AWS EU
    "/api/clouds/3",  # AWS US-West
    "/api/clouds/4",  # AWS AP-Singapore
    "/api/clouds/5",  # AWS AP-Tokyo
    "/api/clouds/6",  # AWS US-Oregon
    "/api/clouds/7",  # AWS SA-Sao Paulo
    "/api/clouds/8",  # AWS AP-Sydney
    "/api/clouds/9",  # AWS EU-Frankfurt
    "/api/clouds/10", # AWS China
    "/api/clouds/11", # AWS US-Ohio
    "/api/clouds/12", # AWS AP-Seoul
    "/api/clouds/13", # AWS EU-London
    "/api/clouds/14"  # AWS CA-Central
)

$token = Invoke-RestMethod -Method Post -Uri "https://$($accountEndpoint)/api/oauth2" `
    -Headers @{ "X-API-Version"="1.5"; "X-Account"=$accountId } `
    -Body @{
        grant_type="refresh_token";
        refresh_token=$refreshToken
    }

$currentCloudAccounts = Invoke-RestMethod -Method Get `
    -Uri "https://$($accountEndpoint)/api/cloud_accounts" `
    -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId }

$currentCloudAccounts = $currentCloudAccounts | Select-Object created_at, updated_at, `
    @{name="self";expression={$_.links | Where-Object {$_.rel -eq 'self'} | Select-Object -ExpandProperty href}},`
    @{name="cloud";expression={$_.links | Where-Object {$_.rel -eq 'cloud'} | Select-Object -ExpandProperty href}},`
    @{name="account";expression={$_.links | Where-Object {$_.rel -eq 'account'} | Select-Object -ExpandProperty href}}

foreach ($cloudHref in $cloudHrefs) {
    if($currentCloudAccounts.cloud -contains $cloudHref) {
        # Cloud/Region is already registered, update cloud account
        $requestVerb = "Put"
        $url = $currentCloudAccounts | Where-Object {$_.cloud -eq $cloudHref} | Select-Object -ExpandProperty self
        $body = "cloud_account[creds][aws_access_key_id]=$accessKeyIdEncoded&cloud_account[creds][aws_secret_access_key]=$secretAccessKeyEncoded"
    }
    else {
        # Cloud/Region is not registered, create cloud account
        $requestVerb = "Post"
        $url = "/api/cloud_accounts"
        $body = "cloud_account[cloud_href]=$cloudHref&cloud_account[creds][aws_account_number]=$accountNumberEncoded&cloud_account[creds][aws_access_key_id]=$accessKeyIdEncoded&cloud_account[creds][aws_secret_access_key]=$secretAccessKeyEncoded"
    }

    Invoke-RestMethod -Method $requestVerb `
        -Uri "https://$($accountEndpoint)$($url)" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body $body
}

# Create Credentials
Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=AWS_ACCOUNT_ID&credential[value]=$accountNumberEncoded&credential[description]=AWS Account ID"

Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=AWS_ACCESS_KEY_ID&credential[value]=$accessKeyIdEncoded&credential[description]=AWS Access Key ID"

Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=AWS_SECRET_ACCESS_KEY&credential[value]=$secretAccessKeyEncoded&credential[description]=AWS Secret Access Key"
