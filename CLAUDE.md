# 키움 MCP 계좌 매핑

키움 앱 키는 계좌 단위라서 계좌마다 `kiwoom-exec-*` 서버가 따로 있다.
사용자가 계좌 별칭을 말하면 아래 서버의 도구만 사용한다.

| 별칭 | MCP 서버 | 환경변수 |
| --- | --- | --- |
| 메인 | `kiwoom-exec-main` | `APP_KEY_MAIN`, `APP_SECRET_MAIN`, `KIWOOM_MODE_MAIN` |
| 서브 | `kiwoom-exec-sub` | `APP_KEY_SUB`, `APP_SECRET_SUB`, `KIWOOM_MODE_SUB` |
| 자동 | `kiwoom-exec-auto` | `APP_KEY_AUTO`, `APP_SECRET_AUTO`, `KIWOOM_MODE_AUTO` |
| 띨띨 | `kiwoom-exec-ttil` | `APP_KEY_TTIL`, `APP_SECRET_TTIL`, `KIWOOM_MODE_TTIL` |

- 계좌가 지정되지 않은 조회·주문 요청은 어느 계좌인지 먼저 묻는다. 임의로 고르지 않는다.
- 주문(`kiwoom_order_submit`)은 실행 전에 계좌 별칭, 종목, 수량, 가격을 사용자에게 다시 확인한다.
- API 명세 검색은 계좌와 무관하게 `kiwoom-spec`을 쓴다.
