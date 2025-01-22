<#
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

function Get-CWLogResults(){
     <#
    .SYNOPSIS
        This cmdlet is run as part of other functions to simplify the process of querying log groups
    .DESCRIPTION
        This cmdlet is run as part of other functions to simplify the process of querying log groups
    .PARAMETER LogGroup
        This required parameter is a string value for LogGroup that will be used as part of the query. For example: "/aws/internet-monitor/WorkSpaces/byCity"
    .PARAMETER queryString
        This is a required string parameter that, will run on the LogGroup and example would be:
            $queryString = @'
            fields clientLocation.city as City, 
            clientLocation.subdivision as Subdivision,
            clientLocation.country as Country,
            clientLocation.networkName as NetworkName,
            clientLocation.asn as ASN,
            clientLocation.ipv4Prefixes.0 as IPPrefix 
            | dedup City, Subdivision, Country, NetworkName, ASN, IPPrefix
            '@ 
 
    .PARAMETER region
        This required parameter is a string value for the region you are building the WorkSpaces report for. For example, 'us-east-1'. 
    .PARAMETER TimeinHours
        This is the time in hours to go back. For example 24 hours for the last day of log.
    .PARAMETER queryTimeout
        This is the time in seconds for the query to run

    .EXAMPLE
        Get-CWLogResults -LogGroup "/aws/internet-monitor/WorkSpaces/byCity" -query $queryString -region us-east-1 -TimeinHours 24 -queryTimeout 30
    #> 
    [CmdletBinding()] 
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogGroup,
        [Parameter(Mandatory=$true)]
        [string]$query,
        [Parameter(Mandatory=$true)]
        [string]$region,
        [Parameter(Mandatory=$false)]
        [int]$TimeinHours = 24,
        [Parameter(Mandatory=$false)]
        [int]$queryTimeout = 30
    )
    $logResult = @()
    #Initiate the query
    $queryId = Start-CWLQuery -QueryString $query -LogGroupName $LogGroup -StartTime ((Get-Date -UFormat %s) - (3600 * $TimeinHours)) -EndTime (Get-Date -UFormat %s) -Region $region 
    write-host "Starting query for the queryId: $queryId"
    $queryComplete=$false
    $timer=0
    while (!$queryComplete -and ($timer -lt $queryTimeout)) {
        $queryStatus = Get-CWLQueryResult -QueryId $queryId -Region $region 
        if ($queryStatus.Status -eq "Complete"){
            $queryComplete=$true
        }
        write-host "Query is still running, checking query again in 1 second"
        Start-Sleep -Seconds 1
        $timer=$timer+1
    } 
    if ($queryComplete){
        foreach ($row in $queryStatus.Results) {
            $entry = New-Object -TypeName PSobject
                foreach ($field in $row){
                    $entry | Add-Member -NotePropertyName $field.Field -NotePropertyValue $field.Value
                }
            $logResult += $entry
        }
        return $logResult
    }
    else{
        write-host "Query timed out, try increasing the timeout settings"
        return $null
    }
}

#Function Get Connected WorkSpace Locations: Returns a detailed list of locations where WorkSpaces are connected
function Get-ConnectedWSLocations(){
     <#
    .SYNOPSIS
        This cmdlet is run to get the location details from the CloudWatch Internet Monitor where WorkSpaces are currently connected.
    .DESCRIPTION
        This cmdlet is run to get the location details from the CloudWatch Internet Monitor where WorkSpaces are currently connected.
    .PARAMETER LogGroup
        This required parameter is a string value for LogGroup that will be used as part of the query. For example: "/aws/internet-monitor/WorkSpaces/byCity"
    .PARAMETER region
        This required parameter is a string value for the region you are building the WorkSpaces report for. For example, 'us-east-1'.
    .PARAMETER CSVOutput
        This is an optional boolean parameter that, if set to $true, will export the inventory as a CSV file in your working directory named: 'ConnectedWorkSpaceLocation-REGION-MM-dd-yyyy_HH-mm.csv'.
        If set to $false or unspecified, the inventory will return as a PowerShell object.  
    .PARAMETER TimeinHours
        This is the time in hours to go back. For example 24 hours for the last day of log.
    .PARAMETER queryTimeout
        This is the time in seconds for the query to run
    .EXAMPLE
        Get-ConnectedWSLocations -LogGroup "/aws/internet-monitor/WorkSpaces/byCity" -region us-east-1 -CSVOutput $true -TimeinHours 2184 -queryTimeout 30
    #>
    [CmdletBinding()] 
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogGroup,
        [Parameter(Mandatory=$true)]
        [string]$region,
        [bool]$CSVOutput=$true,
        [Parameter(Mandatory=$false)]
        [int]$TimeinHours = 24,
        [Parameter(Mandatory=$false)]
        [int]$queryTimeout = 30
    )
    $queryString = @'
    fields clientLocation.city as City, 
    clientLocation.subdivision as Subdivision,
    clientLocation.country as Country,
    clientLocation.networkName as NetworkName,
    clientLocation.asn as ASN,
    clientLocation.ipv4Prefixes.0 as IPPrefix 
    | filter trafficInsights.timeToFirstByte.currentExperience.serviceName = "WORKSPACES"
    | dedup City, Subdivision, Country, NetworkName, ASN, IPPrefix 
'@
    $CWIMResults = Get-CWLogResults -LogGroup $LogGroup -query $queryString -region $region -TimeinHours $TimeinHours -queryTimeout $queryTimeout
    if ($null -ne $CWIMResults){
        if($CSVOutput){
            $csvCreationTime = Get-Date -format "MM-dd-yyyy_HH-mm"
            $CWIMResults | Export-Csv -Path ".\ConnectedWorkSpaceLocations-$region-$csvCreationTime.csv"
            Write-Host "WorkSpace location info exported to CSV file: .\ConnectedWorkSpaceLocations-$region-$csvCreationTime.csv"
        }else{
            return $CWIMResults
        }
    }
    else{
        write-host "No matching WorkSpaces for the query, review the parameters and validate that WorkSpaces events are setup: https://docs.aws.amazon.com/workspaces/latest/adminguide/cloudwatch-events.html"
    }
}

#Function Get Connected WorkSpace Locations: Returns a detailed list of locations where WorkSpaces are connected
function Get-ImpactedWorkSpaces(){
     <#
    .SYNOPSIS
        This cmdlet is run to get the location details from the CloudWatch Internet Monitor where WorkSpaces are currently connected.
    .DESCRIPTION
        This cmdlet is run to get the location details from the CloudWatch Internet Monitor where WorkSpaces are currently connected.
    .PARAMETER CWIMLogGroup
        This required parameter is a string value for the CloudWatch Internet Monitor LogGroup that will be used as part of the query. For example: "/aws/internet-monitor/WorkSpaces/byCity"
    .PARAMETER region
        This required parameter is a string value for the region you are building the WorkSpaces report for. For example, 'us-east-1'. 
    .PARAMETER CSVOutput
        This is an optional boolean parameter that, if set to $true, will export the inventory as a CSV file in your working dirctory named: 'ImpactedWorkSpaces-REGION-MM-dd-yyyy_HH-mm.csv'.
        If set to $false or unspecified, the inventory will return as a PowerShell object.  
    .PARAMETER TimeinHours
        This is the time in hours to go back. For example 24 hours for the last day of log.
    .PARAMETER queryTimeout
        This is the time in seconds for the query to run
    .EXAMPLE
        Get-ImpactedWorkSpaces -Subdivision "Georgia" -CWIMLogGroup "/aws/internet-monitor/WorkSpaces/byCity" -WorkSpaceAccessLogGroup "/aws/events/WorkSpacesAccessLogs" -region us-east-1 -CSVOutput $true-TimeinHours 2184 -queryTimeout 30
    #>
    [CmdletBinding()] 
    param(
        [Parameter(Mandatory=$true)]
        [string]$CWIMLogGroup,
        [Parameter(Mandatory=$true)]
        [string]$WorkSpaceAccessLogGroup,
        [Parameter(Mandatory=$true)]
        [string]$region,
        [bool]$CSVOutput=$true,
        [Parameter(Mandatory=$false)]
        [string]$IP,
        [Parameter(Mandatory=$false)]
        [string]$ASN,
        [Parameter(Mandatory=$false)]
        [string]$NetworkName,
        [Parameter(Mandatory=$false)]
        [string]$Country,
        [Parameter(Mandatory=$false)]
        [string]$Subdivision,
        [Parameter(Mandatory=$false)]
        [int]$TimeInHours = 24,
        [Parameter(Mandatory=$false)]
        [int]$queryTimeout = 30

    )

     #First we need to query the CWIM to with the parameters and need to get the IP address to do the next lookup in WorkSpaces Access Events
    $queryCWIMString = @'
    fields clientLocation.city as City, 
    clientLocation.subdivision as Subdivision,
    clientLocation.country as Country,
    clientLocation.networkName as NetworkName,
    clientLocation.asn as ASN,
    clientLocation.ipv4Prefixes.0 as IPPrefix
    | filter trafficInsights.timeToFirstByte.currentExperience.serviceName = "WORKSPACES" 
    | dedup City, Subdivision, Country, NetworkName, ASN, IPPrefix
'@
#Next pull a list of WorkSpaces
    $queryWksString = @'
    fields detail.clientIpAddress as IPAddress, 
    detail.clientPlatform as ClientPlatform,
    detail.clientVersion as ClientVersion,
    detail.directoryId as directoryId,
    detail.loginTime as loginTime,
    detail.workspaceId as WorkSpaceId
    | filter `detail-type` = "WorkSpaces Access"
'@

    $requiredModule = Confirm-RequiredModule
    if($requiredModule){    
        $CWIMResults =Get-CWLogResults -LogGroup $CWIMLogGroup -query $queryCWIMString -region $region -TimeinHours $TimeinHours -queryTimeout $queryTimeout
        #Apply the filters based on the input
        $filteredCWIMResults = $CWIMResults
        
        if($IP -ne ""){
            $filteredCWIMResults = $filteredCWIMResults | Where-Object { ($_.IPPrefix -like ($IP + ".*")) } | Select-Object City,Subdivision,Country,NetworkName,ASN,IPPrefix
        }
        if($ASN -ne ""){
            $filteredCWIMResults = $filteredCWIMResults| Where-Object { ($_.ASN -like ($ASN + "*")) } | Select-Object City,Subdivision,Country,NetworkName,ASN,IPPrefix
        }
        if($NetworkName -ne ""){
            $filteredCWIMResults = $filteredCWIMResults | Where-Object { ($_.NetworkName -like ($NetworkName + "*")) } | Select-Object City,Subdivision,Country,NetworkName,ASN,IPPrefix
        }
        if($Subdivision -ne ""){
            $filteredCWIMResults = $filteredCWIMResults | Where-Object { ($_.Subdivision -like ($Subdivision + "*")) } | Select-Object City,Subdivision,Country,NetworkName,ASN,IPPrefix
        }
        if($Country -ne ""){
            $filteredCWIMResults = $filteredCWIMResults | Where-Object { ($_.Country -like ($Country + "*")) } | Select-Object City,Subdivision,Country,NetworkName,ASN,IPPrefix
        }

        #We need to get all of the Connections information with WorkSpaces
        write-host "Starting the query for CloudWatch Internet Monitor logs"
        $WorkSpaceAccessResults = Get-CWLogResults -LogGroup $WorkSpaceAccessLogGroup -query $queryWksString -region $region -TimeinHours $TimeinHours -queryTimeout $queryTimeout
        # Now we will call Get-WorkSpacesInventory to get information on each WS and append to the $WorkSpaceAccessResults object
        $WorkSpaceAccessandInfo = @()
        write-host "Getting a list of all of the WorkSpaces in region $region"
        $workSpacesList = Get-WorkSpacesInventory -csv $false -connectedStatus $false -region $region 
        foreach ($WS in $WorkSpaceAccessResults){
            $WSInfo = $workSpacesList | Where-Object { ($_.WorkSpaceId -like ($WS.WorkSpaceId + "*")) } | Select-Object UserName, Protocol, Email
            $WS | Add-Member -NotePropertyName "UserName" -NotePropertyValue $WSInfo.UserName
            $WS | Add-Member -NotePropertyName "Protocol" -NotePropertyValue $WSInfo.Protocol
            $WorkSpaceAccessandInfo += $WS
        }
        $impactedWS = @()
        foreach ($record in $filteredCWIMResults){
            $ipFilter = $record.IPPrefix.Split('.')
            $newString =$ipFilter[0]+"."+$ipFilter[1]+"."+$ipFilter[2]
            $filteredItems = $WorkSpaceAccessandInfo | Where-Object { ($_.IPAddress -like ($newString + ".*")) } | Select-Object IPAddress,ClientPlatform,ClientVersion,directoryId,loginTime,WorkSpaceId,UserName, Protocol, Email
            $filteredItems | Add-Member -NotePropertyName "IP_Prefix" -NotePropertyValue $record.IPPrefix
            $filteredItems | Add-Member -NotePropertyName "City" -NotePropertyValue $record.City
            $filteredItems | Add-Member -NotePropertyName "Country" -NotePropertyValue $record.Country
            $filteredItems | Add-Member -NotePropertyName "Subdivision" -NotePropertyValue $record.Subdivision
            $filteredItems| Add-Member -NotePropertyName "NetworkName" -NotePropertyValue $record.NetworkName
            $filteredItems| Add-Member -NotePropertyName "ASN" -NotePropertyValue $record.ASN
            $impactedWS+=$filteredItems
        }
        if ($null -ne $impactedWS){
            if($CSVOutput){
                $csvCreationTime = Get-Date -format "MM-dd-yyyy_HH-mm"
                $impactedWS | Export-Csv -Path ".\ImpactedWorkSpaces-$region-$csvCreationTime.csv"
            }else{
                return $impactedWS
            }
        }
        else{
            write-host "No matching WorkSpaces for the query, review the parameters and validate that WorkSpaces events are setup: https://docs.aws.amazon.com/workspaces/latest/adminguide/cloudwatch-events.html"
        }
    }else{
        Write-Host "Required amazon-workspaces-admin-module module not found. See `'https://github.com/aws-samples/amazon-workspaces-admin-module`'."
    }
}

function Get-CWIMHealthAlerts(){
     <#
    .SYNOPSIS
        This cmdlet is run to get Health Events from the CloudWatch Internet Monitor where WorkSpaces are currently connected.
    .DESCRIPTION
        This cmdlet is run to get Health Events from the CloudWatch Internet Monitor where WorkSpaces are currently connected.
    .PARAMETER region
        This required parameter is a string value for the region you are building the WorkSpaces report for. For example, 'us-east-1'. 
    .PARAMETER CSVOutput
        This is an optional boolean parameter that, if set to $true, will export the inventory as a CSV file in your working dirctory named: 'CWIMHealthAlerts-REGION-MM-dd-yyyy_HH-mm.csv'.
        If set to $false or unspecified, the inventory will return as a PowerShell object.  
    .EXAMPLE
        Get-ConnectedWSLocations -region us-east-1 -CSVOutput $true
    #> 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$region,
        [bool]$CSVOutput=$true
    )
    $events = Get-CWIMHealthEventList -MonitorName WorkSpaces -Region $region
    $logResult = @()
    foreach ($event in $events){
        $eventDetail = Get-CWIMHealthEvent -EventId $event.EventId -MonitorName WorkSpaces -Region $region
        $locationDetails =$eventDetail.ImpactedLocations
        foreach ($detail in $locationDetails){
            $entry = New-Object -TypeName PSobject
            $entry | Add-Member -NotePropertyName "Status" -NotePropertyValue $event.Status
            $entry | Add-Member -NotePropertyName "ASName" -NotePropertyValue $detail.ASName
            $entry | Add-Member -NotePropertyName "ASN" -NotePropertyValue $detail.ASNumber
            $entry | Add-Member -NotePropertyName "EventType" -NotePropertyValue $detail.CausedBy.NetworkEventType
            $entry | Add-Member -NotePropertyName "City" -NotePropertyValue $detail.City
            $entry | Add-Member -NotePropertyName "Country" -NotePropertyValue $detail.Country
            $entry | Add-Member -NotePropertyName "Metro" -NotePropertyValue $detail.Metro
            $entry | Add-Member -NotePropertyName "ServiceLocation" -NotePropertyValue $detail.ServiceLocation
            $entry | Add-Member -NotePropertyName "Subdivsion" -NotePropertyValue $detail.Subdivision
            $logResult += $entry
        }
    }
    if($CSVOutput){
        $csvCreationTime = Get-Date -format "MM-dd-yyyy_HH-mm"
        $logResult | Export-Csv -Path "$PSScriptRoot\CWIMHealthAlerts-$region-$csvCreationTime.csv"
    }else{
        return $logResult
    }
}

function Confirm-RequiredModule(){
     <#
    .SYNOPSIS
        This cmdlet is run to check for the required WorkSpaces admin module. This is required to get the username.
    .DESCRIPTION
        This cmdlet is run to check for the required WorkSpaces admin module. This is required to get the username.
    #> 
    if(Get-Module -name amazon-workspaces-admin-module){
        Write-Host "amazon-workspaces-admin-module module found."
        return $true
    }else{
        $response = Read-Host "The required module for this cmdlet is not imported. Would you like to import it? (y/n)"
        if($response.ToUpper() -eq "Y"){
            if(-not (Test-Path "$PSScriptRoot/amazon-workspaces-admin-module.psm1")){
                Invoke-WebRequest -Uri https://raw.githubusercontent.com/aws-samples/amazon-workspaces-admin-module/refs/heads/main/amazon-workspaces-admin-module.psm1 -Out $PSScriptRoot/amazon-workspaces-admin-module.psm1
            }
            try{
                Import-Module $PSScriptRoot/amazon-workspaces-admin-module.psm1
                return $true
            }
            catch{
                Write-Host "Error importing the admin module"
            }
        }else{
            Write-Host "User declined to have required module imported."
            return $false
        }
    }
}

function Get-WksEolClients(){
     <#
    .SYNOPSIS
        This cmdlet is run to get a list of WorkSpaceIds and Users that are using an End of Life client or technical guidance client as of January 9th 2025.
    .DESCRIPTION
        This cmdlet is run to get a list of WorkSpaceIds and Users that are using an End of Life client or technical guidance client as of January 9th 2025.
    .PARAMETER LogGroup
        This required parameter is a string value for LogGroup where WorkSpaces access logs that will be used as part of the query. For example: "/aws/events/WorkSpacesAccessLogs".
    .PARAMETER region
        This required parameter is a string value for the region you are building the WorkSpaces report for. For example, 'us-east-1'.
    .PARAMETER CSVOutput
        This is an optional boolean parameter that, if set to $true, will export the inventory as a CSV file in your working dirctory named: 'ConnectedWorkSpaceLocation-REGION-MM-dd-yyyy_HH-mm.csv'.
        If set to $false or unspecified, the inventory will return as a PowerShell object.  
    .PARAMETER TimeinHours
        This is the time in hours to go back. For example 24 hours for the last day of log.
    .PARAMETER queryTimeout
        This is the time in seconds for the query to run.
    .PARAMETER userLookup
        This is an optional boolean parameter that, if set to $true, will export the the username for the WorkSpace.
    .EXAMPLE
        Get-WksEolClients -LogGroup "/aws/events/WorkSpacesAccessLogs" -region us-east-1 -CSVOutput $true -TimeinHours 2184 -queryTimeout 30
    #> 
    [CmdletBinding()] 
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogGroup,
        [Parameter(Mandatory=$true)]
        [string]$region,
        [bool]$CSVOutput=$true,
        [Parameter(Mandatory=$false)]
        [int]$TimeinHours = 24,
        [Parameter(Mandatory=$false)]
        [int]$queryTimeout = 30,
        [Parameter(Mandatory=$false)]
        [bool]$userLookup=$false

    )
    #query to get Technical guidance and EOL WorkSpaces clients as of 1/9/2025
    $queryString = @'
    fields @timestamp, @message 
    | fields account 
    | fields region, detail.clientPlatform, detail.clientVersion, detail.workspaceId, detail.clientIpAddress 
    | parse detail.clientVersion "*.*.*" as majorVersion, minorVersion, subVersion 
    | filter ( (detail.clientPlatform = "Windows" or detail.clientPlatform = "OSX") and (majorVersion < 5 or (majorVersion = 5 and minorVersion < 22) or (majorVersion = 5 and minorVersion = 22 and subVersion < 1) ) or ( detail.clientPlatform = "Linux" and (majorVersion < 2024 or (majorVersion <= 2024 and minorVersion <= 5)) ) or ( detail.clientPlatform = "Android" and (majorVersion < 5 or (majorVersion = 5 and minorVersion = 0 and subVersion < 1)) ) ) 

'@ 
    #run the query to get the logs
    $logResults = Get-CWLogResults -LogGroup $LogGroup -query $queryString -region $region -TimeinHours $TimeinHours -queryTimeout $queryTimeout

    $wsInventory = $null
    #if the userNameLokup is set to true, query the WorkSpaces details to get that information.
    if ($userLookup){
        try{
            #First we need to use the WorkSpaces Admin module to get a list of WorkSpaces: https://github.com/aws-samples/amazon-workspaces-admin-module
            $requiredModule = Confirm-RequiredModule
            if($requiredModule){
                $wsInventory = Get-WorkSpacesInventory -region $region
            }
            else{
                Write-Host "Get-WorkSpacesInventory is not imported. See `'https://github.com/aws-samples/amazon-workspaces-admin-module`'"
            }
        }
        catch{
            $requiredModule = $false
            Write-Output "Powershell Module has not returned WorkSpaces, please verify your permissions."
        }
        if ($requiredModule){
            $entryIndex = 0
            foreach ($userSearch in $logResults){
                try{
                    $wsId = $userSearch.'detail.WorkSpaceId'
                    $wksUserName = $wsInventory |Where-Object {$_.WorkSpaceId -like $wsId} | Select-Object UserName
                    $logResults[$entryIndex] | Add-Member -NotePropertyName 'WorkSpaceUsername' -NotePropertyValue $wksUserName.UserName
                }
                catch{
                    $logResults[$entryIndex] | Add-Member -NotePropertyName 'WorkSpaceUsername' -NotePropertyValue "WorkSpace not found"
                }
                $entryIndex++
            }
        }
    }

    if($CSVOutput){
        $csvCreationTime = Get-Date -format "MM-dd-yyyy_HH-mm"
        $logResults | Export-Csv -Path "$PSScriptRoot\WSEOLClients-$region-$csvCreationTime.csv"
    }else{
        return $logResults
    }

}