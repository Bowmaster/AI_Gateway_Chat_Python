<#
.SYNOPSIS
    Setup script for AI Gateway Chat client

.DESCRIPTION
    Creates a virtual environment, installs dependencies, and optionally starts the client.

.PARAMETER StartClient
    If specified, starts the chat client after setup

.PARAMETER ServerUrl
    Override the default server URL (can also be set via AI_SERVER_URL environment variable)

.EXAMPLE
    .\setup.ps1
    # Sets up the environment only

.EXAMPLE
    .\setup.ps1 -StartClient
    # Sets up the environment and starts the client

.EXAMPLE
    .\setup.ps1 -StartClient -ServerUrl "http://192.168.1.100:8080"
    # Sets up, configures server URL, and starts the client
#>

param(
    [switch]$StartClient,
    [string]$ServerUrl
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  AI Gateway Chat - Setup Script" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Check Python installation
Write-Host "[1/4] Checking Python installation..." -ForegroundColor Yellow
$PythonCmd = $null

# Try different Python commands
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $version = & $cmd --version 2>&1
        if ($version -match "Python 3\.") {
            $PythonCmd = $cmd
            Write-Host "  Found: $version" -ForegroundColor Green
            break
        }
    } catch {
        continue
    }
}

if (-not $PythonCmd) {
    Write-Host "  ERROR: Python 3 not found!" -ForegroundColor Red
    Write-Host "  Please install Python 3.8 or later from https://python.org" -ForegroundColor Yellow
    exit 1
}

# Create virtual environment
$VenvPath = Join-Path $ScriptDir "venv"
Write-Host ""
Write-Host "[2/4] Setting up virtual environment..." -ForegroundColor Yellow

if (Test-Path $VenvPath) {
    Write-Host "  Virtual environment already exists at: $VenvPath" -ForegroundColor Green
} else {
    Write-Host "  Creating virtual environment..."
    & $PythonCmd -m venv $VenvPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to create virtual environment!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Created: $VenvPath" -ForegroundColor Green
}

# Activate virtual environment
Write-Host ""
Write-Host "[3/4] Activating virtual environment..." -ForegroundColor Yellow
$ActivateScript = Join-Path $VenvPath "Scripts\Activate.ps1"

if (-not (Test-Path $ActivateScript)) {
    Write-Host "  ERROR: Activation script not found!" -ForegroundColor Red
    exit 1
}

# Source the activation script
. $ActivateScript
Write-Host "  Activated" -ForegroundColor Green

# Install dependencies
Write-Host ""
Write-Host "[4/4] Installing dependencies..." -ForegroundColor Yellow
$RequirementsPath = Join-Path $ScriptDir "requirements.txt"

if (Test-Path $RequirementsPath) {
    & pip install -r $RequirementsPath --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to install dependencies!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "  WARNING: requirements.txt not found, skipping..." -ForegroundColor Yellow
}

# Setup complete
Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "To start the chat client manually:" -ForegroundColor Cyan
Write-Host "  .\venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host "  python chat.py" -ForegroundColor White
Write-Host ""

# Set server URL if provided
if ($ServerUrl) {
    $env:AI_SERVER_URL = $ServerUrl
    Write-Host "Server URL set to: $ServerUrl" -ForegroundColor Cyan
    Write-Host ""
}

# Start client if requested
if ($StartClient) {
    Write-Host "Starting AI Gateway Chat..." -ForegroundColor Cyan
    Write-Host ""

    $ChatScript = Join-Path $ScriptDir "chat.py"
    & python $ChatScript
}
