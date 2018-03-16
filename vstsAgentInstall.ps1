try
{   

    md \agent
    cd \agent
    $agentInstallDir = Get-Location
    [string] $agentInstallPath = $null
    
    # Construct the agent folder under the specified drive.
    #$agentInstallDir = $DriveLetter + ":"
    try
    {
        # Create the directory for this agent.
        $agentInstallPath = Join-Path -Path $agentInstallDir -ChildPath "\vstsAgent.zip"
        New-Item -ItemType Directory -Force -Path $agentInstallPath | Out-Null
    }
    catch
    {
        $agentInstallPath = $null       
    }    
   
}
finally
{
    popd
}

function Download-AgentPackage
{
    [CmdletBinding()]
    param(
        [string] $VstsAccount,
        [string] $VstsUserPassword
    )
    
    # Create a temporary directory where to download from VSTS the agent package (agent.zip).
    $agentTempFolderName = Join-Path $env:temp ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $agentTempFolderName | Out-Null

    $agentPackagePath = "$agentTempFolderName\agent.zip"
    $serverUrl = "https://$VstsAccount.visualstudio.com"
    $vstsAgentUrl = "$serverUrl/_apis/distributedtask/packages/agent/win7-x64?`$top=1&api-version=3.0"
    $vstsUser = "AzureDevTestLabs"

    $maxRetries = 3
    $retries = 0
    do
    {
        try
        {
            $basicAuth = ("{0}:{1}" -f $vstsUser, $vstsUserPassword) 
            $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
            $basicAuth = [System.Convert]::ToBase64String($basicAuth)
            $headers = @{ Authorization = ("Basic {0}" -f $basicAuth) }

            $agentList = Invoke-RestMethod -Uri $vstsAgentUrl -Headers $headers -Method Get -ContentType application/json
            $agent = $agentList.value
            if ($agent -is [Array])
            {
                $agent = $agentList.value[0]
            }
            Invoke-WebRequest -Uri $agent.downloadUrl -Headers $headers -Method Get -OutFile "$agentPackagePath" | Out-Null
            break
        }
        catch
        {
            $exceptionText = ($_ | Out-String).Trim()
                
            if (++$retries -gt $maxRetries)
            {
                Write-Error "Failed to download agent due to $exceptionText"
            }
            
            Start-Sleep -Seconds 1 
        }
    }
    while ($retries -le $maxRetries)

    return $agentPackagePath
}

function New-AgentInstallPath
{
   
    md \agent
    cd \agent
    $agentInstallDir = Get-Location
    [string] $agentInstallPath = $null
    
    # Construct the agent folder under the specified drive.
    #$agentInstallDir = $DriveLetter + ":"
    try
    {
        # Create the directory for this agent.
        $agentInstallPath = Join-Path -Path $agentInstallDir -ChildPath "\vstsAgent.zip"
        New-Item -ItemType Directory -Force -Path $agentInstallPath | Out-Null
    }
    catch
    {
        $agentInstallPath = $null
        Write-Error "Failed to create the agent directory at $installPathDir."
    }
    
    return $agentInstallPath
}

function Get-AgentInstaller
{
    param(
        [string] $InstallPath
    )

    $agentExePath = [System.IO.Path]::Combine($InstallPath, 'config.cmd')

    if (![System.IO.File]::Exists($agentExePath))
    {
        Write-Error "Agent installer file not found: $agentExePath"
    }
    
    return $agentExePath
}

function Extract-AgentPackage
{
    [CmdletBinding()]
    param(
        [string] $PackagePath,
        [string] $Destination
    )
  
    Add-Type -AssemblyName System.IO.Compression.FileSystem 
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$PackagePath", "$Destination")
    
}


