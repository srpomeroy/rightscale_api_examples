# The following example will allow you to register/update your AzureRM Subscription credentials with the Flexera Cloud Management Platform

# Cloud Href Reference: https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html
# API Docs: https://reference.rightscale.com/api1.5/resources/ResourceCloudAccounts.html
# Refresh Token: https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps
# Google IAM: https://docs.rightscale.com/clouds/google/getting_started/google_connect_gce_to_rightscale.html

$accountEndpoint = "<YOUR_ACCOUNT_ENDPOINT>" # Cloud Management Endpoints: https://docs.rightscale.com/api/general_usage.html#endpoints
$accountId = "<YOUR_ACCOUNT_NUMBER>" # Your CMP Account ID
$refreshToken = "<YOUR_REFRESH_TOKEN>" # Your Refresh Token https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps

$projectId = "<YOUR_GOOGLE_PROJECT_ID>" # Google Project ID
$clientEmail = "<YOUR_GOOGLE_IAM_USER_EMAIL>" # Client Email
$privateKey = "<YOUR_GOOGLE_IAM_USER_PRIVATE_KEY>" # Client Private Key

Add-Type -AssemblyName System.Web
$projectIdEncoded = [System.Web.HttpUtility]::UrlEncode($projectId)
$clientEmailEncoded = [System.Web.HttpUtility]::UrlEncode($clientEmail)
$privateKeyEncoded = [System.Web.HttpUtility]::UrlEncode($privateKey)

# Google Cloud Href Reference: https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html#supported-clouds-and-parameters-google
$cloudHrefs = @(
    "/api/clouds/2175" # Google
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
        $body = "cloud_account[creds][client_email]=$clientEmailEncoded&cloud_account[creds][prviate_key]=$privateKeyEncoded"
    }
    else {
        # Cloud/Region is not registered, create cloud account
        $requestVerb = "Post"
        $url = "/api/cloud_accounts"
        $body = "cloud_account[cloud_href]=$cloudHref&cloud_account[creds][project]=$projectIdEncoded&cloud_account[creds][client_email]=$clientEmailEncoded&cloud_account[creds][prviate_key]=$privateKeyEncoded"
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
        -Body "credential[name]=GCE_PROJECT_ID&credential[value]=$projectIdEncoded&credential[description]=Google Project ID"

Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=GCE_PLUGIN_ACCOUNT&credential[value]=$clientEmailEncoded&credential[description]=Google Client Email"

Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=GCE_PLUGIN_PRIVATE_KEY&credential[value]=$privateKeyEncoded&credential[description]=Google Client Private Key"
