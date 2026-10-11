
function Write-DeploymentLog {
    param(
        [string]$Path,
        [string]$Message
    )

    $LogDirectory = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force |
            Out-Null
    }

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $Path -Value "[$Time] $Message"
}

function Invoke-MyAppDeployment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [Parameter(Mandatory)]
        [string]$RegistryPath,

        [Parameter(Mandatory)]
        [string]$LogPath,

        [string]$Version = "1.0.0"
    )

    $ErrorActionPreference = "Stop"

    try {
        Write-DeploymentLog -Path $LogPath `
            -Message "Deployment started."

        if (-not (Test-Path -LiteralPath $SourcePath `
                    -PathType Container)) {
            throw "Source folder does not exist."
        }

        New-Item -Path $DestinationPath `
            -ItemType Directory -Force | Out-Null

        Write-DeploymentLog -Path $LogPath `
            -Message "Destination folder created."

        Copy-Item -Path (Join-Path $SourcePath '*') `
            -Destination $DestinationPath -Recurse -Force

        Write-DeploymentLog -Path $LogPath `
            -Message "Files copied successfully."

        New-Item -Path $RegistryPath -Force | Out-Null

        New-ItemProperty -Path $RegistryPath `
            -Name "InstallPath" `
            -Value $DestinationPath `
            -PropertyType String -Force | Out-Null

        New-ItemProperty -Path $RegistryPath `
            -Name "Version" `
            -Value $Version `
            -PropertyType String -Force | Out-Null

        Write-DeploymentLog -Path $LogPath `
            -Message "Registry key and values created."

        Write-DeploymentLog -Path $LogPath `
            -Message "Deployment completed successfully."
    }
    catch {
        Write-DeploymentLog -Path $LogPath `
            -Message "ERROR: $($_.Exception.Message)"
        throw
    }
}
