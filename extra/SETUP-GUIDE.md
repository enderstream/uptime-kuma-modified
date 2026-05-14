# Uptime Kuma (Windows Notification Edition) 설치 가이드

이 포크는 원본 Uptime Kuma에 **Windows 네이티브 토스트 알림 provider**를 추가하고, **Windows 부팅(로그온) 시 서버를 자동 실행**하도록 구성한 버전이다. 이 문서 하나만 따라 하면 팀원 PC에서 동일하게 동작한다.

문제 발생 시: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 참고.

---

## 동작 구조

```text
[모니터링 대상 서버] ← Uptime Kuma 가 주기적으로 헬스체크
                         ↓ (다운 감지)
                   [Uptime Kuma 서버 (node server/server.js)]
                         ↓ (node-notifier 호출)
                   [Windows 토스트 알림]
```

별도의 헬스체커 프로세스나 Webhook 리스너 없이, Uptime Kuma 프로세스 하나가 모니터링과 알림을 모두 처리한다.

---

## 사전 준비 (1회)

**Node.js 20.4.0 이상** 설치 (<https://nodejs.org/>, LTS 권장).

설치 확인:

```powershell
node --version
```

---

## 설치 (3단계)

### 1. 저장소 클론

```powershell
git clone https://github.com/enderstream/uptime-kuma-modified.git
cd uptime-kuma-modified
```

### 2. 원클릭 설치 스크립트 실행

`extra\install.bat` **더블클릭**.

- UAC 창이 뜨면 "예"로 관리자 권한 승인
- 자동으로 다음을 수행한다:
  1. `npm ci` — 의존성 설치 (`node-notifier` 포함, 별도 설치 불필요)
  2. `npm run build` — 프론트엔드 빌드
  3. 작업 스케줄러에 `UptimeKumaServer` 태스크 등록 (로그온 시 자동 실행)

완료 메시지가 나오면 종료.

### 3. 서버 시작 (즉시 시작하려면)

다음 로그온부터는 자동 실행된다. 지금 바로 시작하려면 PowerShell에서:

```powershell
schtasks /run /tn "UptimeKumaServer"
```

브라우저에서 <http://localhost:3001> 접속 → 정상 응답 확인.

---

## 알림 설정 (UI)

서버가 떠 있는 상태에서 <http://localhost:3001> 접속.

### 1. 최초 1회 — Windows Notification 알림 등록

1. 우상단 사용자 메뉴 → **설정 → 알림**
2. **새 알림 설정** 클릭
3. 알림 종류 드롭다운에서 **Windows Notification** 선택
4. 별명: 예) `내 PC 토스트`
5. **테스트** 클릭 → 우측 하단에 토스트가 떠야 정상
6. **기본적으로 활성화** 체크
7. **기존 모니터에 모두 적용** 체크
8. **저장**

### 2. 모니터마다 알림 빈도 설정

기본값은 다운 감지 시 **최초 1회만** 알림을 보낸다. 1분마다 반복 알림을 받으려면:

1. 모니터 목록에서 알림을 받고 싶은 모니터 클릭
2. **편집** 클릭
3. **연속적인 다운으로 판단해 알림을 재전송할 기준 횟수** 항목 찾기
4. 값을 **1** 로 변경
   - `0` = 최초 1회만 알림
   - `1` = 매 체크 주기(60초)마다 계속 알림
5. **저장**

---

## 모니터링 대상 등록

이건 자동화하지 않는다 (사용자별로 다름). UI 좌상단 **+** 버튼 → 모니터 종류(HTTP(s) / Ping 등) 선택 → URL/IP 입력 → 저장.

---

## 일상 운영 명령어

PowerShell에서:

```powershell
# 서버 즉시 시작
schtasks /run /tn "UptimeKumaServer"

# 서버 중지
schtasks /end /tn "UptimeKumaServer"

# 상태 확인 (상태코드 0x41301 = 실행 중, 정상)
schtasks /query /tn "UptimeKumaServer"

# 프로세스 확인
Get-Process node -ErrorAction SilentlyContinue
```

---

## 제거

`extra\uninstall.bat` **더블클릭** (관리자 권한 자동 요청).

- 작업 스케줄러 태스크 제거
- 프로젝트 파일 / `node_modules` 는 그대로 남는다 (필요하면 폴더째 수동 삭제)

---

## 업데이트 받기

```powershell
cd uptime-kuma-modified
git pull
extra\install.bat
```

`install.bat`을 다시 돌리면 의존성/빌드/태스크 등록이 모두 갱신된다 (idempotent).
