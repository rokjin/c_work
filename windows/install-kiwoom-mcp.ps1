#Requires -Version 5.1
<#
  키움 MCP 로컬 설치 (Windows) — Claude Desktop + Claude Code
  참고: https://github.com/Kiwoom-Securities/Kiwoom-REST-API/blob/main/SETUP-MCP.md

  실행 전: Claude 앱을 완전히 종료 (시스템 트레이 아이콘 > 종료)
  실행:    PowerShell에서
           powershell -ExecutionPolicy Bypass -File .\install-kiwoom-mcp.ps1

  - 앱 키는 이 창에서만 입력받아 설정 파일에 기록합니다 (화면·로그에 출력하지 않음).
  - Enter만 누르면 기존 값을 유지하고, 기존 값이 없으면 placeholder(your_app_key)를 씁니다.
  - 기존 설정 파일은 *.bak-날짜 로 백업한 뒤 kiwoom-* 항목만 추가/갱신합니다.
#>
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'

# ---- 계좌 / 주문 설정 ------------------------------------------------------
$Accounts = @(
    @{ alias = '메인'; name = 'main' },
    @{ alias = '서브'; name = 'sub'  },
    @{ alias = '자동'; name = 'auto' },
    @{ alias = '띨띨'; name = 'ttil' }
)
$AllowOrders = $true   # 주문 도구(kiwoom_order_*) 켜기. 끄려면 $false

$RepoUrl  = 'https://github.com/Kiwoom-Securities/Kiwoom-REST-API'
$RepoDir  = Join-Path $env:LOCALAPPDATA 'mcp\Kiwoom-REST-API'
$Targets  = @(
    @{ client = 'Claude Desktop'; path = (Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'); type = $false },
    @{ client = 'Claude Code';    path = (Join-Path $env:USERPROFILE '.claude.json');                  type = $true  }
)

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function ToSlash($p) { return ($p -replace '\\', '/') }

# ---- Step 0. uv / git ------------------------------------------------------
Step 'uv 확인'
$uv = (Get-Command uv -ErrorAction SilentlyContinue).Source
if (-not $uv) {
    $uv = Join-Path $env:USERPROFILE '.local\bin\uv.exe'
    if (-not (Test-Path $uv)) {
        Write-Host 'uv 설치 중...'
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    }
    if (-not (Test-Path $uv)) { throw "uv 설치 실패: $uv 없음" }
}
$uv = ToSlash (Get-Item $uv).FullName
& $uv --version

Step 'git 확인'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git이 없습니다. "winget install Git.Git" 실행 후 새 PowerShell 창에서 다시 실행하세요.'
}
git --version

# ---- Step 3~5. repository + dependency ------------------------------------
Step "repository 준비: $RepoDir"
if (Test-Path (Join-Path $RepoDir '.git')) {
    $origin = git -C $RepoDir remote get-url origin
    if ($origin -notlike "$RepoUrl*") { throw "$RepoDir 는 다른 저장소입니다 ($origin). 삭제하지 않고 중단합니다." }
    Write-Host '이미 clone되어 있어 그대로 사용합니다.'
} elseif (Test-Path $RepoDir) {
    throw "$RepoDir 가 이미 있지만 git 저장소가 아닙니다. 삭제하지 않고 중단합니다."
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $RepoDir) | Out-Null
    git clone $RepoUrl $RepoDir
}
foreach ($d in 'mcp_spec', 'mcp_exec') {
    if (-not (Test-Path (Join-Path $RepoDir $d))) { throw "$d 디렉터리가 없습니다." }
}
$repo = ToSlash (Get-Item $RepoDir).FullName

Step 'dependency 설치 (첫 실행은 수 분 걸림)'
& $uv sync --frozen --directory "$repo/mcp_spec"; if ($LASTEXITCODE) { throw 'mcp_spec sync 실패' }
& $uv sync --frozen --directory "$repo/mcp_exec"; if ($LASTEXITCODE) { throw 'mcp_exec sync 실패' }

# ---- 앱 키 입력 (이 창에서만) ---------------------------------------------
function Read-Secret($prompt) {
    $s = Read-Host -Prompt $prompt -AsSecureString
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}
Step '계좌별 앱 키 입력 (Enter = 기존 값 유지 / 나중에 입력)'
$acc = @()
foreach ($a in $Accounts) {
    Write-Host "`n[$($a.alias)] 계좌" -ForegroundColor Yellow
    $key = Read-Secret '  APP_KEY'
    $sec = Read-Secret '  APP_SECRET'
    do {
        $mode = (Read-Host '  모드 real/demo (Enter = 기존 값, 없으면 demo)').Trim().ToLower()
    } while ($mode -and $mode -ne 'real' -and $mode -ne 'demo')
    $acc += @{ alias = $a.alias; name = $a.name; key = $key; secret = $sec; mode = $mode }
}

# ---- Step 7~10. config merge + tools/list 검증 (Python, stdlib only) ------
$py = @'
import json, os, shutil, subprocess, sys, threading, time
from pathlib import Path

P = json.loads(os.environ["KW_PAYLOAD"])
UV, REPO, ORDERS = P["uv"], P["repo"], P["orders"]


def server_defs(old):
    spec = {"command": UV, "args": ["run", "--frozen", "--directory", f"{REPO}/mcp_spec", "kiwoom-spec-mcp"]}
    defs = {"kiwoom-spec": spec}
    for a in P["accounts"]:
        name = f"kiwoom-exec-{a['name']}"
        prev = (old.get(name) or {}).get("env") or {}
        env = {
            "APP_KEY": a["key"] or prev.get("APP_KEY") or "your_app_key",
            "APP_SECRET": a["secret"] or prev.get("APP_SECRET") or "your_app_secret",
            "KIWOOM_MODE": a["mode"] or prev.get("KIWOOM_MODE") or "demo",
        }
        if ORDERS:
            env["KIWOOM_MCP_ALLOW_ORDERS"] = "1"
        defs[name] = {"command": UV, "args": ["run", "--frozen", "--directory", f"{REPO}/mcp_exec", "kiwoom-exec-mcp"], "env": env}
    return defs


def merge(t):
    path = Path(t["path"])
    data = {}
    if path.exists():
        text = path.read_text(encoding="utf-8-sig")
        data = json.loads(text) if text.strip() else {}
        backup = path.with_name(f"{path.name}.bak-{time.strftime('%Y%m%d%H%M%S')}")
        shutil.copy2(path, backup)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
    servers = data.setdefault("mcpServers", {})
    for name, d in server_defs(servers).items():
        servers[name] = {"type": "stdio", **d} if t["type"] else d
    out = json.dumps(data, ensure_ascii=False, indent=2)
    json.loads(out)  # syntax 검증
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(out, encoding="utf-8")
    os.replace(tmp, path)
    json.loads(path.read_text(encoding="utf-8"))
    return [n for n in servers if n.startswith("kiwoom")]


def tools_list(cmd, env):
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            text=True, encoding="utf-8", env={**os.environ, **env})
    timer = threading.Timer(120, proc.kill)
    timer.daemon = True
    timer.start()

    def send(m):
        proc.stdin.write(json.dumps(m) + "\n")
        proc.stdin.flush()

    def recv(i):
        while True:
            line = proc.stdout.readline()
            if not line:
                raise RuntimeError("server closed stdout")
            try:
                m = json.loads(line)
            except ValueError:
                continue
            if m.get("id") == i:
                if "error" in m:
                    raise RuntimeError(m["error"])
                return m["result"]

    try:
        send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "setup-verify", "version": "0"}}})
        recv(1)
        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        return [t["name"] for t in recv(2)["tools"]]
    finally:
        timer.cancel()
        proc.terminate()


ok = True
print("\n== 설정 파일 merge")
for t in P["targets"]:
    try:
        names = merge(t)
        print(f"  OK  {t['client']}: {t['path']}  ({', '.join(names)})")
    except Exception as e:  # 기존 파일은 그대로 둔다
        ok = False
        print(f"  FAIL {t['client']}: {t['path']} -> {e}")

print("\n== MCP initialize -> tools/list 검증")
exec_expected = 5 if ORDERS else 3
for name, d in server_defs({}).items():
    exp_tool, exp_n = ("spec_search", 4) if name == "kiwoom-spec" else ("kiwoom_query", exec_expected)
    env = {"KIWOOM_MCP_ALLOW_ORDERS": "1"} if (ORDERS and name != "kiwoom-spec") else {}
    try:
        tools = tools_list([d["command"], *d["args"]], env)
        good = exp_tool in tools and len(tools) == exp_n
        ok &= good
        print(f"  {'OK ' if good else 'FAIL'} {name}: {len(tools)}개 {tools}")
    except Exception as e:
        ok = False
        print(f"  FAIL {name}: {e}")

placeholders = [a["alias"] for a in P["accounts"] if not (a["key"] and a["secret"])]
print("\n앱 키를 이번에 입력하지 않은 계좌:", ", ".join(placeholders) if placeholders else "없음")
sys.exit(0 if ok else 1)
'@

$payload = @{
    uv = $uv; repo = $repo; orders = $AllowOrders; accounts = $acc
    targets = @($Targets | ForEach-Object { @{ client = $_.client; path = $_.path; type = $_.type } })
} | ConvertTo-Json -Depth 5 -Compress

$tmpPy = Join-Path $env:TEMP "kiwoom_mcp_setup_$PID.py"
[IO.File]::WriteAllText($tmpPy, $py, (New-Object Text.UTF8Encoding $false))
try {
    $env:KW_PAYLOAD = $payload
    & $uv run --frozen --directory "$repo/mcp_spec" python -I $tmpPy
    $rc = $LASTEXITCODE
} finally {
    Remove-Item Env:KW_PAYLOAD -ErrorAction SilentlyContinue
    Remove-Item $tmpPy -ErrorAction SilentlyContinue
    $payload = $null; $acc = $null
}

# ---- 공인 IP (키움 IP 등록용) ---------------------------------------------
Step '이 PC의 공인 IP'
try { $ip = Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10; Write-Host "  $ip  <- 키움 개발자센터 > API 사용신청 > IP 등록 (계좌 4개 모두)" -ForegroundColor Green }
catch { Write-Host '  확인 실패 — 브라우저에서 https://api.ipify.org 로 확인하세요.' }

if ($rc -ne 0) { Write-Host "`n설치 검증 실패 — 위 FAIL 항목을 확인하세요." -ForegroundColor Red; exit 1 }
Write-Host "`n키움 MCP 로컬 설치 완료. Claude 앱을 다시 실행하세요." -ForegroundColor Green
Write-Host '  설정 파일에 앱 키가 들어 있으니 커밋·공유·클라우드 동기화하지 마세요.'
