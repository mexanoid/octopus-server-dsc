configuration Main
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [PSCredential]
        $OctopusAdminCredential,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]
        $OctopusWebListenPrefix,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]
        $ResourcesPackage
        )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName OctopusDSC
    Import-DscResource -ModuleName SqlServerDsc
    Import-DscResource -ModuleName StorageDsc
    Import-DSCResource -ModuleName NetworkingDsc

    Node "localhost"
    {
        File CreateInstallMediaDir
        {
            Type = 'Directory'
            DestinationPath = 'C:\InstallMedia'
            Ensure = "Present"
        }

        xRemoteFile DownloadSqlISO {
            Uri = "$ResourcesPackage"
            DestinationPath = "C:\InstallMedia\en_sql_server_2017_developer_x64_dvd_11296168.iso"
            MatchSource = $true
            DependsOn   = '[File]CreateInstallMediaDir'
        }

        MountImage MountISO
        {
            ImagePath   = 'C:\InstallMedia\en_sql_server_2017_developer_x64_dvd_11296168.iso'
            DriveLetter = 'S'
            DependsOn   = '[xRemoteFile]DownloadSqlISO'
        }

        WaitForVolume WaitForISO
        {
            DriveLetter      = 'S'
            RetryIntervalSec = 5
            RetryCount       = 10
            DependsOn   = '[MountImage]MountISO'
        }

        WindowsFeature 'NetFramework45'
        {
            Name   = 'NET-Framework-45-Core'
            Ensure = 'Present'
        }

        SqlSetup InstallDefaultInstance
        {
            Action                 = "Install"
            SourcePath             = 'S:\'
            InstanceName           = 'MSSQLSERVER'
            Features               = 'SQLENGINE'
            SQLSysAdminAccounts    = @('Administrators')
            UpdateEnabled          = 'False'
            ForceReboot            = $false
            DependsOn              = '[WindowsFeature]NetFramework45', '[WaitForVolume]WaitForISO', '[MountImage]MountISO', '[xRemoteFile]DownloadSqlISO', '[File]CreateInstallMediaDir'
        }

        cOctopusServer OctopusServer
        {
            Ensure = "Present"
            State = "Started"
            Name = "OctopusServer"
            DownloadUrl = "https://octopus.com/downloads/latest/WindowsX64/OctopusServer"
            SqlDbConnectionString = "Data Source=(local);Initial Catalog=Octopus;Integrated Security=True;"
            OctopusAdminCredential = $OctopusAdminCredential
            HomeDirectory = "C:\Octopus"
            ForceSSL = $false
            ListenPort = 10943
            WebListenPrefix = $OctopusWebListenPrefix
            TaskCap = 10
            DependsOn = '[SqlSetup]InstallDefaultInstance', '[WindowsFeature]NetFramework45'
        }

        cOctopusServerGuestAuthentication "Enable Guest Authentication"
        {
            InstanceName = "OctopusServer"
            Enabled = $true
            DependsOn = '[cOctopusServer]OctopusServer'
        }

        cOctopusServerUsernamePasswordAuthentication "Enable Username/Password Auth"
        {
            InstanceName = "OctopusServer"
            Enabled = $true
            DependsOn = '[cOctopusServer]OctopusServer'
        }

        Firewall EnableBuiltInHTTPFirewallRule
        {
            Name = 'IIS-WebServerRole-HTTP-In-TCP'
            Ensure  = 'Present'
            Enabled = 'True'
            DependsOn = '[cOctopusServer]OctopusServer'
        }

        Firewall EnableBuiltInHTTPSFirewallRule
        {
            Name = 'IIS-WebServerRole-HTTPS-In-TCP'
            Ensure = 'Present'
            Enabled = 'True'
            DependsOn = '[cOctopusServer]OctopusServer'
        }
    }
}
