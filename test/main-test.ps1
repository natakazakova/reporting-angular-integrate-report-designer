# Requires -Version 7

Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' 

function CheckLastExitCode([string]$Operation = "Unknown operation") {
    if ($LastExitCode -ne 0) {
        Write-Host "$Operation failed with exit code: $LastExitCode" -ForegroundColor Red
        Write-Error -ErrorAction Stop "Last exit code: $LastExitCode"
    }
    Write-Host "$Operation completed successfully" -ForegroundColor Green
}

function InstallNpmPackages() {    
    if(-Not(Test-Path .\node_modules\*)) {
        Write-Host "Node modules not found, installing..." 
        Write-Host "Current directory: $(Get-Location)"
        Write-Host "Package.json exists: $(Test-Path package.json)"
        Write-Host "Package-lock.json exists: $(Test-Path package-lock.json)"
        
        try {
            npm ci --verbose | Out-Host
            CheckLastExitCode "npm ci"
        }
        catch {
            Write-Host "npm ci failed: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    } else {
        Write-Host "Node modules already exist, skipping installation" -ForegroundColor Green
    }
}

function LaunchBackend([Parameter(Mandatory)][string]$path) {
    Write-Host "Backend path: $path"

    Push-Location $path
    try {
        Write-Host "Checking backend project files..." 
        Write-Host "ServerApp.csproj exists: $(Test-Path *.csproj)"
        Write-Host "Program.cs exists: $(Test-Path Program.cs)"
        Write-Host ".NET SDK version: $(dotnet --version)"
        
        Write-Host "Starting backend server..." 
        $process = Start-Process dotnet -ArgumentList ('run') -PassThru
        Write-Host "Backend process started with PID: $($process.Id)" -ForegroundColor Green
        Write-Host "Waiting 25 seconds for backend to initialize..." 
        Start-Sleep -Seconds 25 
        
        # Check if process is still running
        if (-not $process.HasExited) {
            Write-Host "Backend process is still running" -ForegroundColor Green
        } else {
            Write-Host "Backend process has exited with code: $($process.ExitCode)" -ForegroundColor Red
            throw "Backend process terminated unexpectedly"
        }
        
        return $process
    } catch {
        Write-Host "Backend launch failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    } finally {
        Pop-Location
    }
}

function LaunchFrontend([Parameter(Mandatory)][string]$path) {
    Write-Host "Frontend path: $path"
    
    Push-Location $path
    try {
        InstallNpmPackages
        
        Write-Host "Checking frontend project files..." 
        Write-Host "package.json exists: $(Test-Path package.json)"
        Write-Host "angular.json exists: $(Test-Path angular.json)"
        Write-Host "src folder exists: $(Test-Path src)"
        
        Write-Host "Starting frontend server..." 
        $process = Start-Process cmd -ArgumentList ('/c', 'npm', 'start') -PassThru
        Write-Host "Frontend process started with PID: $($process.Id)" -ForegroundColor Green
        Write-Host "Waiting 30 seconds for frontend to build and start..." 
        Start-Sleep -Seconds 30
        
        # Check if process is still running
        if (-not $process.HasExited) {
            Write-Host "Frontend process is still running" -ForegroundColor Green
        } else {
            Write-Host "Frontend process has exited with code: $($process.ExitCode)" -ForegroundColor Red
            Write-Host "This might indicate a build failure or configuration issue" 
        }
        
        return $process
    } catch {
        Write-Host "Frontend launch failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    } finally {
        Pop-Location
    }
}

function RunPlaywrightTests() {    
    try {
        # Ensure Playwright browsers are installed
        Write-Host "Checking Playwright browser installation..." 
        npx playwright install --with-deps chromium | Out-Host
        CheckLastExitCode "Playwright browser installation"
        
        # Verify test files exist
        Write-Host "Checking test files..." 
        Write-Host "Playwright config exists: $(Test-Path playwright.config.ts)"
        Write-Host "Test spec exists: $(Test-Path test/playwright.spec.ts)"
        
        # Test connectivity to frontend
        Write-Host "Testing frontend connectivity..." 
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:4200" -TimeoutSec 10 -UseBasicParsing
            Write-Host "Frontend is responsive (HTTP $($response.StatusCode))" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Frontend connectivity test failed: $($_.Exception.Message)" 
            Write-Host "Proceeding with Playwright tests anyway..." 
        }
        
        Write-Host "Running Playwright tests..." 
        npx playwright test --reporter=list | Out-Host
        $exitCode = $LASTEXITCODE

        Write-Host "Playwright test execution completed" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
        Write-Host "Playwright exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
        
        return $exitCode
    } catch {
        Write-Host "Playwright test execution failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Main() {
    Write-Host "MAIN TEST EXECUTION STARTED" -ForegroundColor Magenta
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Host "Execution Policy: $(Get-ExecutionPolicy)"
    Write-Host "Current User: $env:USERNAME"
    Write-Host "Working Directory: $(Get-Location)"
    
    try {
        InstallNpmPackages
        
        Write-Host "Launching backend..." -ForegroundColor Magenta
        $backendProcess = LaunchBackend ./ServerApp
        
        try {
            Write-Host "Launching frontend..." -ForegroundColor Magenta
            $frontendProcess = LaunchFrontend ./angular-report-designer
            
            try {
                Write-Host "Running Playwright tests..." -ForegroundColor Magenta
                $testResult = RunPlaywrightTests
                
                Write-Host "TEST EXECUTION COMPLETED" -ForegroundColor Magenta
                Write-Host "Final test result: $testResult" -ForegroundColor $(if ($testResult -eq 0) { 'Green' } else { 'Red' })
                
                return $testResult
            } finally {
                Write-Host "FRONTEND CLEANUP" 
                try {
                    Write-Host "Stopping frontend process (PID: $($frontendProcess.Id))..." 
                    taskkill.exe /F /T /PID $frontendProcess.Id 2>$null | Out-Host
                    Write-Host "Frontend process stopped" -ForegroundColor Green
                } catch {
                    Write-Host "⚠️  Frontend cleanup warning: $($_.Exception.Message)" 
                }
            }
        } finally {
            Write-Host "BACKEND CLEANUP" 
            try {
                Write-Host "Stopping backend process (PID: $($backendProcess.Id))..." 
                Stop-Process $backendProcess -Force -ErrorAction SilentlyContinue | Out-Host
                Write-Host "Backend process stopped" -ForegroundColor Green
            } catch {
                Write-Host "⚠️  Backend cleanup warning: $($_.Exception.Message)" 
            }
        }
    } catch {
        Write-Host "Main execution failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        throw
    }
}

try {
    Write-Host "SCRIPT EXECUTION STARTED" -ForegroundColor Magenta
    $result = Main
    Write-Host "SCRIPT EXECUTION COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "Final exit code: $result" -ForegroundColor Green
    Exit [int]$result
} catch {
    Write-Host "SCRIPT EXECUTION FAILED" -ForegroundColor Red
    Write-Host "Fatal Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Script Stack Trace:" -ForegroundColor Red
    $_.ScriptStackTrace -split [System.Environment]::NewLine | ForEach-Object { 
        Write-Host "  $_" -ForegroundColor Red 
    }
    Write-Host "Full Exception Details:" -ForegroundColor Red
    Write-Host "$($_.Exception.ToString())" -ForegroundColor Red
    Exit -1
}