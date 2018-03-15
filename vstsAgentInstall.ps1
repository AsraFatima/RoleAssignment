[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
md \agent;
cd \agent;
$cwd = Get-Location;
md \vstsagent.zip

$destinationFolder = $cwd+"\vstsagent.zip"
Invoke-WebRequest "https://github.com/Microsoft/vsts-agent/releases/download/v2.124.0/vsts-agent-win7-x64-2.124.0.zip" -OutFile "\vstsagent.zip" -UseBasicParsing
Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory($agent, "$cwd")
