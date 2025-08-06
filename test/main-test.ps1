# Requires -Version 7

Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' 

function CheckLastExitCode([string]$Operation = "Unknown operation") {
    if ($LastExitCode -ne 0) {
        Write-Host "❌ $Operation failed with exit code: $LastExitCode"
        Write-Error -ErrorAction Stop "Last exit code: $LastExitCode"
    }
    Write-Host "✅ $Operation completed successfully"
}

function InstallNpmPackages() {    
    if(-Not(Test-Path .\node_modules\*)) {
        Write-Host "Node modules not found, installing..." 
        Write-Host "Current directory: $(Get-Location)"
        Write-Host "Package.json exists: $(Test-Path package.json)"
        Write-Host "Package-lock.json exists: $(Test-Path package-lock.json)"
        
        try {
            Write-Host "Installing dependencies (this may take a moment)..."
            npm ci --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ npm dependencies installed successfully"
            }
            CheckLastExitCode "npm ci"
        }
        catch {
            Write-Host "❌ npm ci failed: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Host "✅ Node modules already exist, skipping installation"
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
        Write-Host "✅ Backend process started with PID: $($process.Id)"
        Write-Host "Waiting 25 seconds for backend to initialize..." 
        Start-Sleep -Seconds 25 
        
        # Check if process is still running
        if (-not $process.HasExited) {
            Write-Host "✅ Backend process is still running"
        } else {
            Write-Host "❌ Backend process has exited with code: $($process.ExitCode)"
            throw "Backend process terminated unexpectedly"
        }
        
        return $process
    } catch {
        Write-Host "❌ Backend launch failed: $($_.Exception.Message)"
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
        Write-Host "✅Frontend process started with PID: $($process.Id)"
        Write-Host "Waiting 30 seconds for frontend to build and start..." 
        Start-Sleep -Seconds 30
        
        # Check if process is still running
        if (-not $process.HasExited) {
            Write-Host "✅ Frontend process is still running"
        } else {
            Write-Host "❌ Frontend process has exited with code: $($process.ExitCode)"
            Write-Host "This might indicate a build failure or configuration issue" 
        }
        
        return $process
    } catch {
        Write-Host "❌ Frontend launch failed: $($_.Exception.Message)"
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
            Write-Host "✅ Frontend is responsive (HTTP $($response.StatusCode))"
        } catch {
            Write-Host "⚠️ Frontend connectivity test failed: $($_.Exception.Message)" 
            Write-Host "Proceeding with Playwright tests anyway..." 
        }
        
        Write-Host "Running Playwright tests..." 
        npx playwright test --reporter=list | Out-Host
        $exitCode = $LASTEXITCODE

        Write-Host "Playwright test execution completed"
        Write-Host "Playwright exit code: $exitCode"
        
        return $exitCode
    } catch {
        Write-Host "❌ Playwright test execution failed: $($_.Exception.Message)"
        throw
    }
}

function Main() {
    Write-Host "MAIN TEST EXECUTION STARTED"
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Host "Execution Policy: $(Get-ExecutionPolicy)"
    Write-Host "Current User: $env:USERNAME"
    Write-Host "Working Directory: $(Get-Location)"
    
    try {
        InstallNpmPackages
        
        Write-Host "Launching backend..."
        $backendProcess = LaunchBackend ./ServerApp
        
        try {
            Write-Host "Launching frontend..."
            $frontendProcess = LaunchFrontend ./angular-report-designer
            
            try {
                Write-Host "Running Playwright tests..."
                $testResult = RunPlaywrightTests

                Write-Host "Final test result: $testResult" 
                
                return $testResult
            } finally {
                Write-Host "FRONTEND CLEANUP" 
                try {
                    Write-Host "Stopping frontend process (PID: $($frontendProcess.Id))..." 
                    taskkill.exe /F /T /PID $frontendProcess.Id 2>$null | Out-Host
                    Write-Host "✅ Frontend process stopped"
                } catch {
                    Write-Host "⚠️ Frontend cleanup warning: $($_.Exception.Message)" 
                }
            }
        } finally {
            Write-Host "BACKEND CLEANUP" 
            try {
                Write-Host "Stopping backend process (PID: $($backendProcess.Id))..." 
                Stop-Process $backendProcess -Force -ErrorAction SilentlyContinue | Out-Host
                Write-Host "✅ Backend process stopped"
            } catch {
                Write-Host "⚠️ Backend cleanup warning: $($_.Exception.Message)" 
            }
        }
    } catch {
        Write-Host "❌ Main execution failed: $($_.Exception.Message)"
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
        throw
    }
}

try {
    Write-Host "SCRIPT EXECUTION STARTED"
    $result = Main
    Write-Host "✅ SCRIPT EXECUTION COMPLETED SUCCESSFULLY"
    Write-Host "✅ Final exit code: $result"
    Exit [int]$result
} catch {
    Write-Host "❌ SCRIPT EXECUTION FAILED"
    Write-Host "❌ Fatal Error: $($_.Exception.Message)"
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Script Stack Trace:"
    $_.ScriptStackTrace -split [System.Environment]::NewLine | ForEach-Object { 
        Write-Host "$_" 
    }
    Write-Host "Full Exception Details:"
    Write-Host "$($_.Exception.ToString())"
    Exit -1
}