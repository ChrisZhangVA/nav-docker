﻿# INPUT
#     $auth
#     $protocol
#     $hostname
#     $ServiceTierFolder
#     $navUseSSL
#     $NavDvdPath
#     $servicesUseSSL
#     $certificateThumbprint
#
# OUTPUT
#    $publicWebBaseUrl
#

Write-Host "Modify NAV Service Tier Config File with Instance Specific Settings"
if (Test-Path "$NavDvdPath\Prerequisite Components\DotNetCore" -PathType Container) {
    $PublicWebBaseUrl = "$protocol$hostname"
} else {
    $PublicWebBaseUrl = "$protocol$hostname/NAV/WebClient/"
}
$CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)
$customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value = $auth
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value = $PublicWebBaseUrl
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicSOAPBaseUrl']").Value = "$protocol${hostname}:$portNavSoapSvc/NAV/WS"
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicODataBaseUrl']").Value = "$protocol${hostname}:$portNavODataSvc/NAV/OData"
if ($navUseSSL) {
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='ServicesCertificateThumbprint']").Value = "$certificateThumbprint"
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='ServicesCertificateValidationEnabled']").Value = "false"
}

$CustomConfig.SelectSingleNode("//appSettings/add[@key='SOAPServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()
$CustomConfig.SelectSingleNode("//appSettings/add[@key='ODataServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()
$developerServicesKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesPort']") -ne $null)
if ($developerServicesKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesPort']").Value = $portNavDevSvc
    $customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesEnabled']").Value = "true"
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()
}
$CustomConfig.Save($CustomConfigFile)

if ($servicesUseSSL) {
   $sslPorts |ForEach-Object {
        netsh http add urlacl url=$protocol+:$_/NAV user="NT AUTHORITY\SYSTEM" | Out-Null
        netsh http add sslcert ipport=0.0.0.0:$_ certhash=$certificateThumbprint appid="{00112233-4455-6677-8899-AABBCCDDEEFF}" | Out-Null
    }
}

if ($developerServicesKeyExists) {
    $serverConfigFile = Join-Path $ServiceTierFolder "Microsoft.Dynamics.Nav.Server.exe.config"
    $serverConfig = [xml](Get-Content -Path $serverConfigFile)
    $serverConfig.SelectSingleNode("//configuration/runtime/NetFx40_LegacySecurityPolicy").enabled = "false"
    $serverConfig.Save($serverConfigFile)
}
