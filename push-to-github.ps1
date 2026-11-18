param(
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl,
    [string]$Branch = "main"
)

# Push this build kit to a NEW, EMPTY GitHub repository.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\push-to-github.ps1 -RepoUrl "https://github.com/<user>/<repo>.git"
# A browser login (Git Credential Manager) or a PAT in the URL handles auth.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "== iStoreOS JLC build kit -> GitHub ==" -ForegroundColor Cyan
Write-Host "Target: $RepoUrl  (branch: $Branch)"

if (-not (Test-Path ".git")) {
    git init
    if ($LASTEXITCODE -ne 0) { throw "git init failed" }
}

# .gitattributes owns line endings; do not let Windows autocrlf override it.
git config core.autocrlf false
git config core.safecrlf false

# Normalise any CRLF introduced while files were authored on Windows.
Get-ChildItem -Path . -Recurse -File -Include *.sh,*.py,*.mk,*.dts,*.yml,*.yaml,*.seed,*.md |
    Where-Object { $_.FullName -notmatch '\\\.git\\' } |
    ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $text  = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ($text.Contains("`r")) {
            [System.IO.File]::WriteAllText($_.FullName, $text.Replace("`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
            Write-Host ("  LF-normalised: " + $_.FullName.Substring($PSScriptRoot.Length + 1))
        }
    }

git add -A
if ($LASTEXITCODE -ne 0) { throw "git add failed" }

$status = git status --porcelain
if (-not $status) {
    Write-Host "Nothing to commit (already up to date)." -ForegroundColor Yellow
} else {
    Write-Host "Committing $($status.Count) change(s)..."
    git -c user.name="iStoreOS-Builder" -c user.email="builder@local" commit -m "Add JLC RK3568 8125 iStoreOS build kit"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
}

git branch -M $Branch 2>$null
$existing = git remote get-url origin 2>$null
if ($existing) { git remote set-url origin $RepoUrl } else { git remote add origin $RepoUrl }

Write-Host ""
Write-Host "Pushing... (a GitHub login window may appear)" -ForegroundColor Cyan
git push -u origin $Branch
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "PUSH FAILED." -ForegroundColor Red
    Write-Host "If this is an auth problem, retry with a Personal Access Token:" -ForegroundColor Yellow
    Write-Host "  $($RepoUrl -replace 'https://','https://<USER>:<PAT>@')" -ForegroundColor Yellow
    throw "git push failed"
}

Write-Host ""
Write-Host "== SUCCESS ==" -ForegroundColor Green
Write-Host "The push triggers the build automatically. Watch it here:"
$web = $RepoUrl -replace '\.git$','' -replace 'git@github.com:','https://github.com/'
Write-Host "  $web/actions"
Write-Host ""
Write-Host "When it finishes (~1-3 h), download 'istoreos-jlc-firmware' from the run page."
Write-Host "If it fails, send me 'istoreos-jlc-diagnostics' -> build.log"
