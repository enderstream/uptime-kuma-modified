# Uptime Kuma (Windows Notification Edition) 트러블슈팅

설치 절차는 [SETUP-GUIDE.md](SETUP-GUIDE.md) 참고. 이 문서는 문제 해결과 설계 결정 기록.

---

## 알림 관련

### 토스트가 안 뜬다

체크 순서:

1. **Uptime Kuma 서버가 떠 있는가?**
   ```powershell
   schtasks /query /tn "UptimeKumaServer"
   Get-Process node -ErrorAction SilentlyContinue
   ```
   `0x41301` = 실행 중(정상), 결과 없으면 미실행.

2. **UI 의 알림 설정 화면에서 "테스트" 버튼이 토스트를 띄우는가?**
   - 안 뜨면 Windows 알림 자체가 차단된 상태일 가능성 큼.
   - **설정 → 시스템 → 알림** 에서 "알림 받기" / "집중 모드" 확인.
   - 동일 알림이 짧은 시간 안에 반복 발송되면 Windows가 묶어서 표시할 수 있음.

3. **모니터에 알림이 연결돼 있는가?**
   - 모니터 편집 화면 하단 "알림" 섹션에서 해당 알림이 체크돼 있는지 확인.

4. **첫 알림은 떴는데 이후 반복이 안 온다**
   - 모니터 편집 → "연속적인 다운으로 판단해 알림을 재전송할 기준 횟수" 가 `0` 이면 최초 1회만 발송. `1` 이상으로 설정.

### 알림 본문에 한글이 깨진다

`node-notifier` (SnoreToast 백엔드) 사용 시 한글 정상 표시되는 것이 정상. 깨진다면 별도 환경 문제 — issue로 보고.

---

## 작업 스케줄러 관련

### `schtasks /query` 결과 코드 의미

| 코드 | 의미 |
|---|---|
| `0` | 정상 종료 / 마지막 실행 성공 |
| `0x41301` | 작업 현재 실행 중 (정상) |
| `0x1` | 마지막 실행에서 일반 오류 |
| `0x41306` | 사용자가 중단함 |

### 등록은 됐는데 부팅 후 자동 실행이 안 된다

- `/sc onlogon` 은 **로그온 시점** 트리거. 자동 로그인이 아니라면 사용자가 로그온해야 시작됨.
- `Get-ScheduledTask -TaskName UptimeKumaServer | Select-Object State` 로 상태 확인. `Disabled` 면 작업 스케줄러 GUI 에서 활성화.

### 절대 쓰지 말 것: `/rl highest`

과거 시도 중 `/rl highest` 옵션을 붙여 등록하면 **SYSTEM 권한**으로 실행되어:
- 데스크톱 UI 세션 접근 불가 → 토스트가 떠도 사용자에게 안 보임
- `Get-Process node | Select CommandLine` 로 커맨드라인 조회 불가

현재 `install.bat` 은 일반 사용자 권한으로 등록하므로 이 문제 없음.

### bat 파일 안에 한글 주석을 넣지 말 것

CP949 / UTF-8 인코딩 충돌로 변수가 잘리는 케이스가 있었음. `extra/install.bat`, `uninstall.bat` 은 영문 주석만 사용한다.

---

## 빌드 관련 (참고)

### 과거 vite 8 + sass 호환성 이슈

이전 작업 중 vite 8 환경에서 `vue-multiselect` 의 scss import 가 깨지는 이슈가 있었음. 현재 `package.json` 은 `vite ~5.4.21`, `sass ~1.42.1` 로 고정돼 있어 **현재 버전에서는 발생하지 않는다**.

만약 향후 vite 를 8 이상으로 올릴 때:
- `npm install esbuild` 별도 필요할 수 있음 (vite 8 이 esbuild 를 별도 설치 요구)
- `sass@1.77.8` 로 다운그레이드해도 vue-multiselect 가 깨질 수 있음 — `vue-multiselect` 도 함께 업그레이드 검토

### `npm ci` vs `npm install`

`install.bat` 은 `npm ci` 사용. `package-lock.json` 을 정확히 따라가서 재현성이 높고 빠르다. 단점은 매 실행마다 `node_modules` 를 새로 만든다는 점이지만, 1회성 설치 스크립트로는 문제 없음.

---

## 알림 provider 설계 결정 기록

### 1차: PowerShell 헬스체커 (`healthcheck.ps1`) — 폐기

**접근:** 별도 PowerShell 스크립트가 1분마다 `localhost:3001` 에 HTTP 요청 → 실패 시 Windows 알림.

**문제:**
- Uptime Kuma 자체가 모니터링 도구인데 그 서버를 감시하는 별도 프로세스를 또 만드는 구조 → "감시자의 감시자" 무한 체인.
- Uptime Kuma 가 감시하는 **대상 서버**의 다운 알림과는 완전히 다른 것.

**교훈:** 문제의 본질을 먼저 파악하고 가장 직접적인 해결책 선택.

### 2차: Webhook + 로컬 HTTP 리스너 — 폐기

**접근:** Uptime Kuma → Webhook → 로컬 HTTP 서버(`healthcheck.ps1`) → Windows 알림.

**문제:** 별도 프로세스 필요. 그 프로세스가 죽으면 알림을 못 받는 새 장애 포인트가 생김.

**교훈:** 프로세스를 추가하는 것은 복잡도와 장애 포인트를 늘림.

### 3차: Uptime Kuma notification provider 직접 추가 — 채택

Uptime Kuma 코드에 Windows Notification provider 를 직접 추가. 이 과정에서 알림 백엔드 선택 시도:

| 시도 | 결과 |
|---|---|
| `System.Windows.Forms.NotifyIcon.ShowBalloonTip()` | Windows 10 에서 사실상 deprecated, 안 뜸. PowerShell 호출이 보안정책으로 차단되는 케이스도 있음. |
| `wscript` + VBS Popup | 알림은 뜨지만 한글 깨짐, 토스트가 아닌 구식 메시지박스 |
| `node-notifier` (SnoreToast 내장) | **채택** — Windows 토스트 직접 발송, PowerShell 불필요, 한글 정상 |

---

## 수정/추가된 파일 (개발자 참고)

원본 Uptime Kuma 대비 변경 내역.

### 신규

| 파일 | 용도 |
|---|---|
| `server/notification-providers/windows-notification.js` | Windows 토스트 알림 provider |
| `src/components/notifications/WindowsNotification.vue` | 알림 설정 UI 컴포넌트 |
| `extra/install.bat` | 원클릭 설치 스크립트 (의존성 + 빌드 + 작업 등록) |
| `extra/uninstall.bat` | 작업 스케줄러 태스크 제거 |
| `extra/SETUP-GUIDE.md` | 설치 가이드 |
| `extra/TROUBLESHOOTING.md` | 본 문서 |

### 수정

| 파일 | 변경 내용 |
|---|---|
| `server/notification.js` | `WindowsNotification` import 및 등록 |
| `src/components/notifications/index.js` | Vue 컴포넌트 import 및 등록 |
| `src/components/NotificationDialog.vue` | Push Services 카테고리에 "Windows Notification" 항목 추가 |
| `src/lang/en.json` | `windowsNotificationDescription` 문구 추가 |
| `package.json`, `package-lock.json` | `node-notifier` 의존성 추가 |

### 핵심 코드 (`server/notification-providers/windows-notification.js`)

```javascript
const NotificationProvider = require("./notification-provider");
const notifier = require("node-notifier");

class WindowsNotification extends NotificationProvider {
    name = "windowsNotification";

    async send(notification, msg, monitorJSON = null, heartbeatJSON = null) {
        const okMsg = "Sent Successfully.";
        return new Promise((resolve, reject) => {
            notifier.notify({
                title: "소프트웨어 구매 관리 시스템",
                message: msg,
                sound: true,
                wait: false,
            }, (error) => {
                if (error) {
                    reject(new Error(`Windows Notification failed: ${error.message}`));
                } else {
                    resolve(okMsg);
                }
            });
        });
    }
}

module.exports = WindowsNotification;
```

토스트 제목(`title`)은 현재 `"소프트웨어 구매 관리 시스템"` 으로 하드코딩돼 있다. 다른 용도로 사용한다면 수정.

#### `notifier.notify()` 옵션

| 키 | 설명 |
|---|---|
| `title` | 토스트 제목 |
| `message` | 토스트 본문 (Uptime Kuma 가 생성한 메시지) |
| `icon` | 커스텀 아이콘 경로 (옵션) |
| `sound` | 알림 소리 on/off |
| `wait` | 클릭 대기 여부 |

#### `send()` 파라미터

| 파라미터 | 설명 |
|---|---|
| `msg` | Uptime Kuma 가 생성한 알림 메시지 본문 |
| `monitorJSON.name` | 모니터 이름 (예: `license-hub - FE`) |
| `monitorJSON.url` | 모니터 URL |
| `heartbeatJSON.status` | 상태 (`0` = DOWN, `1` = UP) |
| `notification` | 사용자가 UI 에서 입력한 알림 설정값 |

원하면 `msg` 대신 `${monitorJSON.name}: ${msg}` 형태로 가공해서 토스트 본문에 모니터명을 넣을 수 있다.
