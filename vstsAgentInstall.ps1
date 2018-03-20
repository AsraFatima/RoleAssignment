# Downloads the Visual Studio Online Build Agent, installs on the new machine, registers with the Visual
# Studio Online account, and adds to the specified build agent pool

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Configure strict debugging.
Set-PSDebug -Strict

###################################################################################################

function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

function New-AgentInstallPath
{
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    md \agent1
    cd \agent1
    $agentInstallDir = Get-Location
    [string] $agentInstallPath = $null
    $agentUrl = "https://github.com/Microsoft/vsts-agent/releases/download/v2.124.0/vsts-agent-win7-x64-2.124.0.zip"
    $agentDir =   Join-Path -Path $agentInstallDir -ChildPath "VSTSInstaller"
    New-Item -ItemType Directory -Force -Path $agentDir | Out-Null
    # Construct the agent folder under the specified drive.    
    try
    {
        # Create the directory for this agent.
        $agentInstallPath = Join-Path -Path $agentInstallDir -ChildPath "\vstsAgent.zip"
        New-Item -ItemType Directory -Force -Path $agentInstallPath | Out-Null
        Invoke-WebRequest $agentUrl -OutFile "\vstsagent.zip" -UseBasicParsing
        Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory("\vstsagent.zip", $agentDir)
    }
    catch
    {
        $agentInstallPath = $null
        Write-Error "Failed to create the agent directory at $installPathDir."
    }
    
    return $agentDir
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


function Install-Agent
{
    param(
        $Config
    )

    try
    {
        # Set the current directory to the agent dedicated one previously created.
        pushd -Path $Config.AgentInstallPath

        # The actual install of the agent. Using --runasservice, and some other values that could be turned into paramenters if needed.
        $agentConfigArgs = "--unattended", "--url", $Config.ServerUrl, "--auth", "PAT","--token", $Config.VstsUserPassword, "--pool", $Config.PoolName, "--runasservice"        
        '.\config.cmd' $agentConfigArgs
    }
    finally
    {
        popd
    }
}

###################################################################################################

#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

###################################################################################################

#
# Main execution block.
#

try
{
    $VstsAccount = "msdata"
    $workingDirectory = Get-Location
    $poolName = "AzureStreamAnalytics Service Pool"
    
    Write-Host 'Preparing agent installation location'
    $agentInstallPath = New-AgentInstallPath   
   
    $vstsPAT = "2l2gar3fypbd5x5y33frvy6uehcqi4psj5s446kydgqbdk5ragra"
    $windowsLogonAccount= "NT AUTHORITY\NETWORK SERVICE"
    
    $workDirectory = "_work"   

    Write-Host 'Getting agent installer path'
    $agentExePath = Get-AgentInstaller -InstallPath $agentInstallPath

    # Call the agent with the configure command and all the options (this creates the settings file)
    # without prompting the user or blocking the cmd execution.
    Write-Host 'Installing agent'
    $config = @{
        AgentExePath = $agentExePath
       AgentInstallPath = $agentInstallPath        
       PoolName = $poolName
       ServerUrl = "https://$VstsAccount.visualstudio.com"
       VstsUserPassword = $vstsPAT
       WindowsLogonAccount = $windowsLogonAccount 
        WorkDirectory = $workDirectory     
    }
    Install-Agent -Config $config
    
    Write-Host 'Done'
}
finally
{
    popd
}
