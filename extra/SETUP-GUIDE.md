# Uptime Kuma Windows 알림 설정 가이드

## 개요

Uptime Kuma에 **Windows 네이티브 토스트 알림** notification provider를 추가하여, 모니터링 대상 서버가 다운되면 이 PC에서 바로 알림을 받을 수 있도록 구성한다. 또한 Windows 부팅 시 Uptime Kuma 서버가 자동 실행되도록 작업 스케줄러에 등록한다.

---

## 최종 구조

```
[모니터링 대상 서버] ← Uptime Kuma가 주기적으로 체크
                          ↓ (다운 감지)
                    [Uptime Kuma 서버 (node server/server.js)]
                          ↓ (node-notifier 호출)
                    [Windows 토스트 알림 표시]
```

- 별도 프로세스 없음 (healthcheck.ps1 불필요)
- 별도 Webhook 리스너 없음
- Uptime Kuma 프로세스 하나로 모든 것 처리

---

## 삽질 기록 & 교훈

### 1차 시도: PowerShell 헬스체커 (healthcheck.ps1) — 실패

**접근**: PowerShell 스크립트가 1분마다 localhost:3001에 HTTP 요청 → 실패 시 Windows 알림

**문제점**:
- Uptime Kuma 자체가 모니터링 도구인데, 그 서버를 감시하는 별도 프로세스를 또 만듦
- "감시자의 감시자" 무한 체인 문제 발생
- Uptime Kuma가 감시하는 **대상 서버**의 다운 알림과는 전혀 다른 것
- 결국 Uptime Kuma에 알림 provider를 직접 추가하는 것이 근본적 해결

**교훈**: 문제의 본질을 먼저 파악하고, 가장 직접적인 해결책을 선택할 것

### 2차 시도: Webhook + 로컬 리스너 — 폐기

**접근**: Uptime Kuma → Webhook → 로컬 HTTP 서버(healthcheck.ps1) → Windows 알림

**문제점**:
- 또 별도 프로세스가 필요
- 그 프로세스가 죽으면 알림을 못 받음
- 불필요하게 복잡한 구조

**교훈**: 프로세스를 추가하는 것은 복잡도와 장애 포인트를 늘림

### 3차 시도: Uptime Kuma notification provider 직접 추가 — 채택

**접근**: Uptime Kuma 코드에 Windows Notification provider를 직접 추가

**BalloonTip 시도 (실패)**:
- `System.Windows.Forms.NotifyIcon.ShowBalloonTip()` 사용
- PowerShell에서 직접 실행하면 에러 없이 끝나지만 **알림이 안 뜸**
- Windows 10에서 BalloonTip은 사실상 deprecated
- `exec`로 PowerShell 호출 시 cmd를 거치는데, 이 PC에서 cmd→PowerShell 호출이 보안정책으로 차단됨
- `execFile`로 직접 호출해도 데스크톱 UI 세션 접근 불가로 알림 안 뜸
- `spawn`으로 detached 프로세스로 실행해도 BalloonTip 자체가 이 PC에서 안 됨

**VBScript 시도 (부분 성공)**:
- `wscript`로 VBS Popup 사용
- 알림은 뜨지만 **한글 깨짐** (인코딩 문제)
- 토스트가 아닌 구식 팝업 메시지 박스

**node-notifier 시도 (성공)**:
- `npm install node-notifier`
- SnoreToast를 내장하여 Windows 토스트 알림을 직접 보냄
- PowerShell 불필요, 인코딩 문제 없음, 한글 정상
- 깔끔한 토스트 알림 표시

**교훈**: 
- Windows에서 프로그래밍적으로 토스트 알림을 보내려면 `node-notifier` (SnoreToast) 사용
- BalloonTip은 Windows 10에서 신뢰할 수 없음
- PowerShell 호출은 보안정책에 따라 차단될 수 있음

### 빌드 이슈

- vite 8 + sass 호환성 문제로 빌드 실패
- `npm install sass@1.77.8`로 다운그레이드해도 vue-multiselect scss import 실패
- `npm install esbuild` 필요 (vite 8이 esbuild를 별도 설치 요구)
- `npm run dev`는 vite 5로 실행되어 빌드 이슈 없음
- 프로덕션 빌드 시 sass 버전 주의 필요

### 작업 스케줄러 이슈

- `/rl highest` 옵션으로 등록하면 SYSTEM 권한으로 실행됨 → 프로세스 CommandLine 조회 불가
- `schtasks` 상태코드 `0x41301` = "작업이 현재 실행 중" (정상)
- bat 파일에 한글 주석 넣으면 인코딩 깨져서 변수가 잘림 → 영문만 사용
- `cmd.exe /c` 로 서버 실행하면 cmd 창이 계속 떠있음 → `powershell.exe -WindowStyle Hidden`으로 변경

---

## 수정한 파일 목록

### 새로 생성

| 파일 | 용도 |
|------|------|
| `server/notification-providers/windows-notification.js` | Windows 토스트 알림 provider (node-notifier 사용) |
| `src/components/notifications/WindowsNotification.vue` | 알림 설정 UI 컴포넌트 |

### 수정

| 파일 | 변경 내용 |
|------|-----------|
| `server/notification.js` | WindowsNotification import 및 등록 |
| `src/components/notifications/index.js` | Vue 컴포넌트 import 및 등록 |
| `src/components/NotificationDialog.vue` | Push Services 카테고리에 "Windows Notification" 추가 |
| `src/lang/en.json` | `windowsNotificationDescription` 문구 추가 |
| `extra/install-healthcheck.bat` | UptimeKumaServer만 등록 (HealthCheck 제거) |
| `extra/uninstall-healthcheck.bat` | UptimeKumaServer만 제거 |

### 삭제

| 파일 | 사유 |
|------|------|
| `extra/healthcheck.ps1` | notification provider로 대체되어 불필요 |

### 추가 의존성

```bash
npm install node-notifier
```

---

## 설정 방법

### 1. 서버 자동 실행 등록

`extra/install-healthcheck.bat`을 **관리자 권한**으로 실행:
- 작업 스케줄러에 `UptimeKumaServer` 태스크 등록
- 로그온 시 `node server/server.js` 백그라운드 실행

### 2. Uptime Kuma UI에서 알림 설정

1. `http://localhost:3001` 접속
2. 설정 → 알림 → 알림 종류에서 **"Windows Notification"** 선택
3. 별명 입력 → 테스트 → 저장
4. "기본적으로 활성화" + "기존 모니터에 모두 적용" 체크

### 3. 1분마다 반복 알림 설정

모니터 편집 → **"연속적인 다운으로 판단해 알림을 재전송할 기준 횟수"** 를 **1**로 설정
- 0 = 최초 1회만 알림
- 1 = 매 체크마다(60초) 계속 알림

### 4. 작업 스케줄러 관리

```powershell
# 서버 시작
schtasks /run /tn "UptimeKumaServer"

# 서버 중지
schtasks /end /tn "UptimeKumaServer"

# 등록 제거
extra\uninstall-healthcheck.bat
```

---

## 핵심 코드: windows-notification.js

```javascript
const NotificationProvider = require("./notification-provider");
const notifier = require("node-notifier");

class WindowsNotification extends NotificationProvider {
    name = "windowsNotification";

    async send(notification, msg, monitorJSON = null, heartbeatJSON = null) {
        const okMsg = "Sent Successfully.";
        return new Promise((resolve, reject) => {
            notifier.notify({
                title: "Uptime Kuma",
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

### 커스터마이즈 가능한 옵션

```javascript
notifier.notify({
    title: "제목",           // 토스트 제목
    message: msg,            // 토스트 내용
    icon: "경로",            // 커스텀 아이콘
    sound: true,             // 소리 on/off
    wait: false,             // 클릭 대기 여부
});
```

### send() 파라미터 활용

- `msg` — Uptime Kuma가 생성한 알림 메시지
- `monitorJSON.name` — 모니터 이름 (예: "license-hub - FE")
- `monitorJSON.url` — 모니터 URL
- `heartbeatJSON.status` — 상태 (0=DOWN, 1=UP)
- `notification` — 사용자가 UI에서 설정한 값

---

## 다른 시스템에 적용할 때 체크리스트

1. Node.js >= 20.4.0 설치
2. `npm install` + `npm install node-notifier`
3. `server/notification-providers/windows-notification.js` 생성
4. `server/notification.js`에 provider 등록
5. `src/components/notifications/WindowsNotification.vue` 생성
6. `src/components/notifications/index.js`에 컴포넌트 등록
7. `src/components/NotificationDialog.vue`에 드롭다운 항목 추가
8. `npm run build` (프로덕션용, sass 버전 주의)
9. 작업 스케줄러에 서버 자동 실행 등록
10. UI에서 Windows Notification 알림 설정 + 모니터에 연결
