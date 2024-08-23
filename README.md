## WorkSpaces queries for CloudWatch Internet Monitor 
This repository hosts a PowerShell module to help administrators query the CloudWatch Internet Monitor Logs and get insights into the WorkSpaces connected to a specific ISP, ASN, City, State or Country. WorkSpace administrators can with calling Get-Connected-WSLocations to see details on where users are connecting to WorkSpaces. In addition, the Get-ImpactedWorkSpaces will show details on specific users specified in the parameters. The Get-CWLogResults will allow further custom queries to dive into the logs.

### Usage 
To review cmdlet usage, you can run `Get-Help` against the cmdlets after importing the module. For example:
#### Get Connected WorkSpaces Cmdlet
```powershell
Get-Help Get-ConnectedWSLocations -Full
```

#### Get Connected WorkSpace Locations Cmdlet
```powershell
Get-ConnectedWSLocations -Full
```

#### Get CloudWatch Internet Monitor Health Events Cmdlet
```powershell
Get-Help Get-CWIMHealthEvents -Full
```
#### Get CloudWatch Log Events Cmdlet
```powershell
Get-Help Get-CWLogResults -Full
```

**AWS Identity and Access Management (IAM) permissions**

You must have IAM permissions to call the service APIs. It is a best practice to follow the principle of least privilege. The following policy provides access to APIs needed by the PowerShell Module
<a name="Required-permissions"></a>
# Required permissions

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WorkSpacesCloudWatchMetrics",
      "Action": [
        "logs:DescribeQueries",
	"logs:DescribeLogGroups",
        "logs:GetQueryResults",
        "logs:StartQuery"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
```

### Walkthrough 
For this walkthrough, you use [AWS CloudShell](https://aws.amazon.com/cloudshell/). CloudShell has [PowerShell.Core](https://github.com/PowerShell/PowerShell#user-content-windows-powershell-vs-powershell-core) and [AWS Tools for PowerShell](https://aws.amazon.com/powershell/) already installed. Note that CloudShell runs outside of your environment so it will not be able to get user details from Active Directory. To get these details in your inventory, invoke the `Get-WorkSpacesInventory` cmdlet from a machine that can reach Active Directory with credentials to call `Get-ADUser`. The assumed role within CloudShell will need Identity Access Management permissions to call:

#### Using the Module
1. After authenticating into the [AWS Management Console](https://aws.amazon.com/console/), navigate to [CloudShell](https://console.aws.amazon.com/cloudshell/home?).
2. Switch to PowerShell by invoking `pwsh`.
3. Download the module by invoking `git clone https://github.com/aws-samples/amazon-workspaces-admin-module`.
4. Navigate to the directory by invoking `cd ./amazon-workspaces-admin-module/`
5. Import the module by invoking `Import-Module ./amazon-workspaces-admin-module.psm1 -force`.
6. Download the module by invoking `git clone https://github.com/aws-samples/WorkSpaces-CloudWatch-InternetMonitor-Queries`.
4. Navigate to the directory by invoking `cd ./WorkSpaces-CloudWatch-InternetMonitor-Queries/`
5. Import the module by invoking `Import-Module ./WorkSpaces-CloudWatch-InternetMonitor-Queries.psm1 -force`.
7. Invoke `Get-CWIMHealthAlerts See the **Usage** section for additional usage information.
8. Invoke `Get-ConnectedWSLocations See the **Usage** section for additional usage information.  
9. Invoke `Get-ImpactedWorkSpaces See the **Usage** section for additional usage information. 

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.


