<# 	
 .SYNOPSIS  
 	Install an offline bundle on ESXi without a vCenter connection.
.DESCRIPTION 
	The script copy on a datastore the offline bundle and execute the installation using the ESXCLI interface.
.NOTES  
    Author:  Alessandro Lorusso, alorusso@vmware.com
.PARAMETER Datastorename
    The Name of the datastore used for hosting the offline bundle.
.PARAMETER Hostname
	The ESXi IP address or FQDN
.PARAMETER Filepath
	The filepath of the offline bundle
.PARAMETER dryrun
	By default the script doesn't install the software. Set this parameter to $false to install the VIB
.PARAMETER credential
	It is possible to use PSCredential object to pass the authentication
.EXAMPLE
    .\Install-VIB-VMhost.ps1 -hostname esx-01a.corp.local -filepath c:\n1k.zip -dryrun $false
.EXAMPLE
    Get-VMhost esx-01.corp.local | .\Install-VIB-VMhost.ps1 -filepath c:\n1k.zip 
#>

Param(
	[parameter(valuefrompipeline = $true, mandatory = $true,
		HelpMessage = "Enter the FQDN of the Host")]
		[string]$hostname,
	[parameter(mandatory = $true, HelpMessage = "Enter the Filepath ")]
		[String]$filepath,
    [parameter(mandatory = $false, HelpMessage = "Enter Datastore Name")]
        [String]$datastorename,
    [parameter(mandatory = $false, HelpMessage = 'Enter DryRun $false or $true')]
        [String]$dryrun = $true,
    [parameter(mandatory = $false)]
        [PSCredential]$credential
	)


<#Connection to host#>
if ($credential) {
    $vihost = connect-viserver $hostname -Credential $credential }
else {
$vihost = Connect-VIserver $hostname }

if (!$vihost.IsConnected) { Write-Host "Error on connection" ; exit 1 }

<#Get local datastore#>
if ($datastorename) {
$datastore = Get-Datastore -Server $vihost -name $datastorename
if (!$datastore) { Write-Host "Error datastore not found" ; exit 1}
}
else {
    $numds = get-datastore -server $vihost | Measure-Object
    if ($numds.count -ne 1 ) { Write-Host "More than one datastore found. Please specify the name"; exit 1 }
    $datastore = Get-Datastore -Server $vihost }
    co


<# Datastore size #>
$sizeVIB = (get-item $filepath).Length
$sizeFreeByte = ($datastore.FreeSpaceMB-1024)*1024*1024
if ($sizeVIB -gt $sizeFreeByte) { Write-Host "No Space Available"; return 1 }


<# Copy file on ESXi #>
New-PSDrive -Location $datastore -Name ds -PSProvider VimDatastore -Root "\"
if (!(get-item ds:\temp)) {
    Write-Host "Creating temp folder"
    New-Item -ItemType folder -path ds:\temp
    }
else
    { Write-host "Temp Folder already created"
    }

Copy-DatastoreItem -Item $filepath -Destination ds:\temp\

<# Installation #>
$esxcli = Get-Esxcli -Server $vihost -V2
$installarg = $esxcli.software.vib.install.CreateArgs()
$installarg.depot = "/vmfs/volumes/"+$datastore.name+"/temp/"+(get-item $filepath).Name
$installarg.dryrun = $dryrun
$esxcli.software.vib.install.invoke($installarg)

<# Cleaning Up #> 
Remove-Item ds:\temp
Remove-Psdrive ds
Disconnect-VIServer $vihost
