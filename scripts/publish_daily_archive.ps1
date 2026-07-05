param(
    [string]$Label = "daily",
    [string]$Date = (Get-Date -Format "yyyy-MM-dd")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$dayDir = Join-Path $repoRoot ("每日复盘\" + $Date)
if (-not (Test-Path -LiteralPath $dayDir)) {
    New-Item -ItemType Directory -Path $dayDir | Out-Null
}

$statusPath = Join-Path $dayDir ("git_publish_status_" + $Label + ".json")

function Save-Status {
    param([hashtable]$Data)
    $Data.timestamp = (Get-Date).ToString("s")
    $Data | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statusPath -Encoding UTF8
}

try {
    $changes = git status --porcelain
    if (-not $changes) {
        Save-Status @{
            status = "no_changes"
            label = $Label
            date = $Date
            message = "No changes to commit."
        }
        exit 0
    }

    git add --all

    $commitMessage = "Daily A-share archive $Date $Label"
    git commit -m $commitMessage

    $remote = git remote get-url origin 2>$null
    if (-not $remote) {
        Save-Status @{
            status = "committed_not_pushed"
            label = $Label
            date = $Date
            message = "Committed locally, but no git remote named origin is configured."
            next_step = "Run: git remote add origin <repo-url>"
        }
        exit 0
    }

    $branch = git branch --show-current
    if (-not $branch) {
        $branch = "master"
    }

    git push -u origin $branch
    Save-Status @{
        status = "pushed"
        label = $Label
        date = $Date
        remote = $remote
        branch = $branch
        message = "Committed and pushed successfully."
    }
}
catch {
    Save-Status @{
        status = "failed"
        label = $Label
        date = $Date
        error = $_.Exception.Message
    }
    throw
}
