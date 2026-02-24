<#
.SYNOPSIS
    Gets a fresh Fabric API token from the cached Azure context.
    Designed for unattended/scheduled use - no interactive prompts.

.DESCRIPTION
    Loads the saved Azure context and requests a fresh token for the
    Fabric/Power BI API. Tokens expire in ~60 minutes; this script
    gets a new one at runtime rather than relying on a stale .token file.

    PREREQUISITE: Run this ONE TIME interactively first to save your context:
        Connect-AzAccount
        Save-AzContext -Path "$env:USERPROFILE\.azure\AzureRmContext.json" -Force

.OUTPUTS
    Returns the token string, or throws if authentication fails.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Load saved Azure context
$contextPath = "$env:USERPROFILE\.azure\AzureRmContext.json"
if (-not (Test-Path $contextPath)) {
    throw "No saved Azure context found at '$contextPath'. Run Connect-AzAccount then Save-AzContext interactively first."
}

$context = Get-AzContext -ErrorAction SilentlyContinue
if (-not $context) {
    try {
        Import-AzContext -Path $contextPath -ErrorAction Stop | Out-Null
        $context = Get-AzContext
    } catch {
        throw "Failed to load saved Azure context: $($_.Exception.Message)"
    }
}

if (-not $context) {
    throw "Could not establish Azure context. Re-run Connect-AzAccount interactively to refresh credentials."
}

# Get fresh token (Power BI/Fabric API resource)
$tokenObj = Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api" -ErrorAction Stop

if (-not $tokenObj) {
    throw "Get-AzAccessToken returned nothing. Check Azure context and permissions."
}

# Handle SecureString (newer Az module versions return SecureString)
$token = $null
if ($tokenObj.Token -is [System.Security.SecureString]) {
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token)
    $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
} else {
    $token = $tokenObj.Token
}

if ([string]::IsNullOrEmpty($token) -or $token.Length -lt 100) {
    throw "Token appears invalid (length: $($token.Length)). Check Azure login and permissions."
}

return $token
