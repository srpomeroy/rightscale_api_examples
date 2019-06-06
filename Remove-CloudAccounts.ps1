# The following example will allow you to selectively remove cloud regions from Cloud Management using the rsc command line tool
# It assumes rsc.exe is in the current working directory

# Cloud Href Reference: https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html
# rsc: https://github.com/rightscale/rsc
# API Docs: https://reference.rightscale.com/api1.5/resources/ResourceCloudAccounts.html
# Refresh Token: https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps

$VerbosePreference = "Continue"

# Cloud Hrefs to Remove - https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html
$cloudHrefsToRemove = @(
    "/api/clouds/7", 
    "/api/clouds/8", 
    "/api/clouds/9"
)

# Cloud Management Account Details
$account = "<YOUR_ACCOUNT_NUMBER>"
$endpoint = "<YOUR_ACCOUNT_ENDPOINT>" # Cloud Management Endpoints: https://docs.rightscale.com/api/general_usage.html#endpoints
$refreshToken = "<YOUR_REFRESH_TOKEN>" # Refresh Token https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps

$cloudAccounts = ((.\rsc.exe --account=$account --host=$endpoint --refreshToken=$refreshToken cm15 index /api/cloud_accounts) | ConvertFrom-Json)
foreach ($cloudAccount in $cloudAccounts) {
    $cloudHref = $cloudAccount.links | Where-Object {$_.rel -eq "cloud"} | Select-Object -ExpandProperty href
    $cloudAccountHref = $cloudAccount.links | Where-Object {$_.rel -eq "self"} | Select-Object -ExpandProperty href
    if ($cloudHrefsToRemove -contains $cloudHref) {
        Write-Verbose "Removing Cloud $cloudHref - $cloudAccountHref..."
        .\rsc.exe --account=$account --host=$endpoint --refreshToken=$refreshToken cm15 destroy $cloudAccountHref
    }
}
