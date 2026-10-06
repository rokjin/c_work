# 키움 MCP 설정

이 저장소를 Claude Code(클라우드 세션 포함)로 열면 키움 MCP 서버 2개가 자동으로 준비됩니다.

| 서버 | 역할 | 도구 |
| --- | --- | --- |
| `kiwoom-spec` | API 명세 검색, 예제 코드 | spec_search, spec_show, spec_groups, get_example |
| `kiwoom-exec-main` / `-sub` / `-auto` / `-ttil` | 계좌별(메인/서브/자동/띨띨) 시세·계좌 조회, 주문 | kiwoom_commands, kiwoom_help, kiwoom_query, kiwoom_order_preview, kiwoom_order_submit |

- `scripts/setup-kiwoom-mcp.sh`: SessionStart 훅이 실행. `~/.local/share/mcp/Kiwoom-REST-API`에 clone + `uv sync --frozen`
- `.mcp.json`: 서버 정의 (project scope)
- 주문 도구: 4개 계좌 모두 **켜짐** (`KIWOOM_MCP_ALLOW_ORDERS=1`). 계좌별로 끄려면 `.mcp.json`의 해당 서버에서 그 줄을 삭제
- 별칭 ↔ 서버 매핑은 `CLAUDE.md` 참고

## 앱 키

앱 키는 이 저장소에 **커밋하지 않습니다.** 환경변수로 넣으세요.

앱 키는 계좌 단위이므로 계좌마다 접미사를 붙여 등록합니다 (접미사: `MAIN`, `SUB`, `AUTO`, `TTIL`).

```
APP_KEY_MAIN=...
APP_SECRET_MAIN=...
KIWOOM_MODE_MAIN=real   # 생략 시 demo
```

- 클라우드 세션: 클라우드 환경 설정의 "환경 변수"에 입력. 네트워크 액세스는 사용자 지정으로 `api.kiwoom.com`, `mockapi.kiwoom.com` 허용
- 로컬: 셸에서 `export APP_KEY_MAIN=...` 등

미설정 시 `your_app_key` placeholder가 전달되어, 도구 목록은 보이지만 실제 조회는 인증 오류(8001)가 납니다.
모의투자(`demo`, 기본)와 실전투자(`real`)는 서로 다른 키를 씁니다.

## 내 PC(Windows)에 설치 — 권장

키움 REST API는 등록된 IP에서만 호출됩니다(오류 8050). 클라우드 세션은 외부 IP가 고정되지 않아 등록이 어렵기 때문에 PC 설치를 권장합니다.

1. Claude 앱 완전 종료 (시스템 트레이 아이콘 → 종료)
2. `windows/install-kiwoom-mcp.ps1`을 PC에 저장 후 PowerShell에서 실행
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install-kiwoom-mcp.ps1
   ```
3. 계좌별(메인/서브/자동/띨띨) APP_KEY, APP_SECRET, 모드(real/demo) 입력 — 입력값은 화면에 표시되지 않음, Enter = 기존 값 유지
4. 마지막에 출력되는 공인 IP를 키움 개발자센터 > API 사용신청 > IP 등록 (계좌 4개 모두)
5. Claude 앱 재실행

등록 위치: `%APPDATA%\Claude\claude_desktop_config.json`(Desktop 채팅), `%USERPROFILE%\.claude.json`(Claude Code). 기존 파일은 `*.bak-날짜`로 백업됩니다.
