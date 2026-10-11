
BeforeAll {
    . "$PSScriptRoot\Deploy-App.ps1"

    $script:TestRegistryPath =
        "HKCU:\Software\MyCompany\MyApp.Tests"

    # Mock registry operations so tests do not modify Windows registry.
    Mock New-Item -ParameterFilter {
        $Path -eq $script:TestRegistryPath
    } {
        $script:RegistryKeyCreated = $true
        [pscustomobject]@{ PSPath = $Path }
    }

    Mock New-ItemProperty -ParameterFilter {
        $Path -eq $script:TestRegistryPath
    } {
        $script:RegistryValues[$Name] = $Value
        [pscustomobject]@{ Name = $Name; Value = $Value }
    }
}

Describe "MyApp deployment" {
    BeforeEach {
        $script:TestRoot = Join-Path $env:TEMP (
            "MyAppPester_" + [guid]::NewGuid().ToString("N")
        )

        $script:Source = Join-Path $script:TestRoot "Source"
        $script:Destination = Join-Path $script:TestRoot "InstalledApp"
        $script:Log = Join-Path $script:TestRoot "Logs\Deploy-App.log"
        $script:TestRegistryPath =
            "HKCU:\Software\MyCompany\MyApp.Tests"

        $script:RegistryKeyCreated = $false
        $script:RegistryValues = @{}

        New-Item -Path $script:Source `
            -ItemType Directory -Force | Out-Null

        Set-Content -Path (Join-Path $script:Source "app.txt") `
            -Value "Test application"
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TestRoot) {
            Remove-Item -LiteralPath $script:TestRoot `
                -Recurse -Force
        }
    }

    It "Creates the installation directory" {
        Invoke-MyAppDeployment `
            -SourcePath $script:Source `
            -DestinationPath $script:Destination `
            -RegistryPath $script:TestRegistryPath `
            -LogPath $script:Log

        Test-Path -LiteralPath $script:Destination |
            Should -BeTrue
    }

    It "Copies the application file" {
        Invoke-MyAppDeployment `
            -SourcePath $script:Source `
            -DestinationPath $script:Destination `
            -RegistryPath $script:TestRegistryPath `
            -LogPath $script:Log

        Get-Content (Join-Path $script:Destination "app.txt") |
            Should -Be "Test application"
    }

    It "Creates the registry key" {
        Invoke-MyAppDeployment `
            -SourcePath $script:Source `
            -DestinationPath $script:Destination `
            -RegistryPath $script:TestRegistryPath `
            -LogPath $script:Log

        $script:RegistryKeyCreated | Should -BeTrue
    }

    It "Creates the InstallPath registry value" {
        Invoke-MyAppDeployment `
            -SourcePath $script:Source `
            -DestinationPath $script:Destination `
            -RegistryPath $script:TestRegistryPath `
            -LogPath $script:Log

        $script:RegistryValues["InstallPath"] |
            Should -Be $script:Destination
    }

    It "Creates the Version registry value" {
        Invoke-MyAppDeployment `
            -SourcePath $script:Source `
            -DestinationPath $script:Destination `
            -RegistryPath $script:TestRegistryPath `
            -LogPath $script:Log

        $script:RegistryValues["Version"] | Should -Be "1.0.0"
    }

    It "Writes deployment success messages to the log" {
        Invoke-MyAppDeployment `
            -SourcePath $script:Source `
            -DestinationPath $script:Destination `
            -RegistryPath $script:TestRegistryPath `
            -LogPath $script:Log

        $LogContent = Get-Content $script:Log -Raw
        $LogContent |
            Should -Match "Deployment completed successfully"
    }

    It "Reports an error when the source folder is missing" {
        Remove-Item -LiteralPath $script:Source -Recurse -Force

        {
            Invoke-MyAppDeployment `
                -SourcePath $script:Source `
                -DestinationPath $script:Destination `
                -RegistryPath $script:TestRegistryPath `
                -LogPath $script:Log
        } | Should -Throw "*Source folder does not exist*"

        $LogContent = Get-Content $script:Log -Raw
        $LogContent | Should -Match "ERROR:"
    }
    
    It "Reports an error when file copying fails" {
        Mock Copy-Item {
            throw "Simulated file copy failure"
        }

        {
            Invoke-MyAppDeployment `
                -SourcePath $script:Source `
                -DestinationPath $script:Destination `
                -RegistryPath $script:TestRegistryPath `
                -LogPath $script:Log
        } | Should -Throw "*Simulated file copy failure*"

        $LogContent = Get-Content $script:Log -Raw
        $LogContent | Should -Match "ERROR:"
    }
    
    It "Reports an error when registry key creation fails" {
        Mock New-Item -ParameterFilter {
            $Path -eq $script:TestRegistryPath
        } {
            throw "Simulated registry failure"
        }

        {
            Invoke-MyAppDeployment `
                -SourcePath $script:Source `
                -DestinationPath $script:Destination `
                -RegistryPath $script:TestRegistryPath `
                -LogPath $script:Log
        } | Should -Throw "*Simulated registry failure*"

        $LogContent = Get-Content $script:Log -Raw
        $LogContent | Should -Match "ERROR:"
    }

}
