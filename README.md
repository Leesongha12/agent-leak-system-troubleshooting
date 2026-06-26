# Agent Leak App System Troubleshooting Report

Linux 환경에서 **Memory Leak (OOM)**, **CPU Spike**, **Deadlock** 장애를 재현하고 분석한 트러블슈팅 프로젝트입니다.

본 프로젝트는 운영 환경에서 발생할 수 있는 시스템 장애를 Linux 명령어와 프로그램 로그를 기반으로 분석하고, GitHub Issue 형태로 정리하는 것을 목표로 하였습니다.

---

# 📌 프로젝트 개요

본 프로젝트에서는 `agent-leak-app-x86` 프로그램을 대상으로 대표적인 시스템 장애를 재현하고 원인을 분석하였습니다.

단순히 프로그램을 실행하는 것에 그치지 않고 운영 환경에서 사용할 수 있는 Linux 명령어와 로그를 활용하여 장애를 분석하고 해결 과정을 문서화하였습니다.

---

# 📚 분석 대상

* Memory Leak (OOM)
* CPU Spike
* Deadlock

---

# 🖥 개발 환경

| 항목          | 내용                  |
| ----------- | ------------------- |
| OS          | Ubuntu 22.04 (WSL2) |
| Terminal    | Ubuntu (WSL)        |
| Application | agent-leak-app-x86  |
| User        | songha              |

---

# 📁 프로젝트 구조

```text
agent/
├── api_keys/
│   └── secret.key
├── logs/
├── upload_files/
└── agent-leak-app-x86
```

### 📷 프로젝트 구조

![Project Structure](./screenshots/setup/01_screenshot_folders.png)

---

# ⚙ 사전 환경 구성

## 1. 필수 디렉터리 생성

```bash
mkdir -p ~/agent/logs
mkdir -p ~/agent/upload_files
mkdir -p ~/agent/api_keys
```

## 2. secret.key 생성

```bash
echo "agent_api_key_test" > ~/agent/api_keys/secret.key
```

### 📷 실행 파일 확인

![Application Files](./screenshots/setup/02_app_files.png)

---

# 🌎 환경 변수 설정

프로그램 실행을 위해 다음과 같이 환경 변수를 설정합니다.

```bash
export AGENT_HOME=$HOME/agent
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=$HOME/agent/logs

export MEMORY_LIMIT=512
export CPU_MAX_OCCUPY=50
export MULTI_THREAD_ENABLE=false
```

### 📷 환경 변수 설정

![Environment Variables](./screenshots/setup/03_environment_variables.png)

---

# 🚀 Boot Success

환경 구성이 완료되면 프로그램이 정상적으로 Boot Sequence를 통과합니다.

### 📷 Boot Success

![Boot Success](./screenshots/setup/04_boot_success.png)

---

# 🧠 Memory Leak (OOM)

## Before

환경 변수

```bash
export MEMORY_LIMIT=256
export CPU_MAX_OCCUPY=50
export MULTI_THREAD_ENABLE=true

./agent-leak-app-x86
```

### 실행 결과

* Heap 메모리가 지속적으로 증가
* MemoryGuard가 256MB를 초과한 시점에서 동작
* 프로세스가 SELF-TERMINATED 상태로 종료됨

주요 로그

```text
Current Heap: 25MB
Current Heap: 50MB
Current Heap: 75MB
...
Current Heap: 275MB

Memory limit exceeded (275MB >= 256MB)

SELF-TERMINATED
```

### 📷 OOM 종료 직전 로그

![OOM Before](./screenshots/oom/01_oom_before_self_terminated.png)

### 📷 monitor.sh 관제 결과

![OOM Monitor](./screenshots/oom/02_oom_monitor.png)

---

## After

```bash
export MEMORY_LIMIT=512
export MULTI_THREAD_ENABLE=false
```

### 실행 결과

* Heap 메모리는 증가하지만
* Memory Cache Flushed 수행
* MEMORY RECOVERED 출력
* 프로세스가 종료되지 않고 정상 유지

### 📷 MEMORY_LIMIT=512 실행 결과

![OOM After](./screenshots/oom/03_after_512mb.png)

---

## 분석 결과

| 항목              | 결과            |
| --------------- | ------------- |
| MEMORY_LIMIT 증가 | 프로세스 생존 시간 증가 |
| Heap 증가 패턴      | 지속 발생         |
| 근본 원인           | Memory Leak   |


# ⚡ CPU Spike

## Before

환경 변수

```bash
export CPU_MAX_OCCUPY=10
```

### 실행 결과

CPU 사용량이 임계치인 10%에 도달하면 Cooldown을 수행하여 부하를 완화하는 것을 확인할 수 있습니다.

주요 로그

```text
Current Load : 5%

Current Load : 8%

Current Load : 10%

Peak reached (10%)

Starting cooldown
```

### 📷 CPU Cooldown

![CPU Cooldown](./screenshots/cpu/01_cpu_cooldown.png)

### 📷 top 명령어 확인

![Top CPU](./screenshots/cpu/02_top_cpu.png)

---

## After

환경 변수

```bash
export CPU_MAX_OCCUPY=100
```

### 실행 결과

CPU 사용량 제한을 높인 후 CPU 부하가 지속적으로 증가하였으며, Watchdog 정책에 의해 프로세스가 종료되었습니다.

주요 로그

```text
Current Load : 44%

Current Load : 54%

CPU Threshold Violated!

WATCHDOG

SIGTERM
```

### 📷 Watchdog 종료

![Watchdog SIGTERM](./screenshots/cpu/03_watchdog_sigterm.png)

---

## 분석 결과

| 항목                 | 결과                             |
| ------------------ | ------------------------------ |
| CPU_MAX_OCCUPY=10  | CPU 사용량이 10%에 도달하면 Cooldown 수행 |
| CPU_MAX_OCCUPY=100 | CPU 사용량이 지속적으로 증가              |
| 최종 결과              | Watchdog 정책이 SIGTERM으로 프로세스 종료 |

---

# 🔒 Deadlock

## 환경

```bash
export MULTI_THREAD_ENABLE=true
```

### 실행 결과

멀티스레드 환경에서 두 개의 Worker Thread가 서로 상대 자원을 기다리면서 교착 상태가 발생하였습니다.

주요 로그

```text
Worker-Thread-1

LOCK ACQUIRED

Worker-Thread-2

LOCK ACQUIRED

WAITING

BLOCKED
```

### 📷 WAITING / BLOCKED

![Deadlock Blocked](./screenshots/deadlock/01_blocked_log.png)

---

## 프로세스 확인

```bash
ps -ef | grep agent
```

실행 결과

프로세스는 종료되지 않고 살아있는 상태를 유지하고 있음을 확인할 수 있습니다.

### 📷 PID 존재 확인

![PID Alive](./screenshots/deadlock/02_pid_alive.png)

---

## Thread 확인

```bash
ps -L -p PID
```

실행 결과

여러 개의 Worker Thread가 생성되어 있는 것을 확인할 수 있습니다.

### 📷 Thread 상태

![Thread State](./screenshots/deadlock/03_thread_state.png)

---

## Deadlock 해결

환경 변수

```bash
export MULTI_THREAD_ENABLE=false
```

멀티스레드를 비활성화한 후 정상적으로 실행되는 것을 확인하였습니다.

### 📷 Deadlock 해결

![Deadlock Resolved](./screenshots/deadlock/04_deadlock_resolved.png)

---

### (선택) 프로세스 종료

```bash
kill PID
```

### 📷 Process 종료

![Process Killed](./screenshots/deadlock/04_process_killed.png)

---

## 분석 결과

* Thread-1이 Shared_Memory_A를 점유
* Thread-2가 Socket_Pool_B를 점유
* 두 스레드가 서로 상대 자원을 기다리면서 **Circular Wait**가 발생
* `MULTI_THREAD_ENABLE=false` 설정 후 Deadlock 없이 정상 수행

---

# 🐧 사용한 Linux 명령어

| 기능         | 명령어                    |
| ---------- | ---------------------- |
| 프로세스 확인    | `ps -ef \| grep agent` |
| 스레드 확인     | `ps -L -p PID`         |
| CPU 사용량 확인 | `top`                  |
| 프로세스 종료    | `kill PID`             |

---

# 📝 작성한 GitHub Issues

본 프로젝트에서는 분석 결과를 GitHub Issue 형태로 정리하였습니다.

* Issue #1 : OOM(Memory Leak) 분석
* Issue #2 : CPU Spike 분석
* Issue #3 : Deadlock 분석

---

# 🎯 프로젝트를 통해 학습한 내용

* Linux 환경 변수 구성 방법
* 프로세스(Process) 및 스레드(Thread) 관리
* Memory Leak 분석 절차
* CPU 사용량 모니터링 및 Watchdog 동작 확인
* Deadlock 발생 원인 및 해결 방법
* GitHub Issue 기반 장애 분석 문서 작성

---

# 📖 참고

본 저장소는 Linux 환경에서 발생 가능한 대표적인 시스템 장애를 재현하고, 프로그램 로그와 Linux 명령어를 활용하여 원인을 분석한 학습 프로젝트입니다.

각 장애는 **재현 → 로그 분석 → Linux 명령어 확인 → 원인 분석 → 해결 방법**의 순서로 정리하였으며, 운영 환경에서의 장애 분석 절차를 학습하는 것을 목표로 하였습니다.


---

# 📂 Repository Structure

```text
.
├── README.md
├── screenshots
│   ├── setup
│   │   ├── 01_screenshot_folders.png
│   │   ├── 02_app_files.png
│   │   ├── 03_environment_variables.png
│   │   └── 04_boot_success.png
│   ├── oom
│   │   ├── 01_oom_before_self_terminated.png
│   │   ├── 02_oom_monitor.png
│   │   └── 03_after_512mb.png
│   ├── cpu
│   │   ├── 01_cpu_cooldown.png
│   │   ├── 02_top_cpu.png
│   │   └── 03_watchdog_sigterm.png
│   └── deadlock
│       ├── 01_blocked_log.png
│       ├── 02_pid_alive.png
│       ├── 03_thread_state.png
│       ├── 04_deadlock_resolved.png
│       └── 04_process_killed.png
├── issues
│   ├── issue-1-oom.md
│   ├── issue-2-cpu-spike.md
│   └── issue-3-deadlock.md
└── app
    └── agent-leak-app-x86
```

---

# 📌 Summary

| 장애 유형       | 원인               | 확인 방법               | 해결 방법                                   |
| ----------- | ---------------- | ------------------- | --------------------------------------- |
| Memory Leak | Heap 메모리 지속 증가   | 프로그램 로그, monitor.sh | MEMORY_LIMIT 증가(임시), Memory Leak 수정(근본) |
| CPU Spike   | CPU 사용량 급증       | top, 프로그램 로그        | CPU_MAX_OCCUPY 조정 및 Watchdog 정책 확인      |
| Deadlock    | Circular Wait 발생 | ps, ps -L           | MULTI_THREAD_ENABLE=false 또는 Lock 순서 개선 |

---

# 📖 Key Takeaways

이번 프로젝트를 통해 다음과 같은 내용을 실습하였습니다.

* Linux 환경 변수 설정 및 실행 환경 구성
* 프로세스(Process)와 스레드(Thread) 분석
* Memory Leak(OOM) 원인 분석
* CPU Spike 및 Watchdog 동작 확인
* Deadlock(Circular Wait) 분석 및 해결
* Linux 명령어를 활용한 시스템 모니터링
* GitHub Issue 기반 장애 분석 문서 작성
* Markdown을 활용한 기술 문서 작성 및 스크린샷 문서화

---

# 📚 References

* Ubuntu 22.04 (WSL2)
* Linux Process Management (`ps`, `ps -L`)
* Linux System Monitoring (`top`)
* Agent Leak App 실습 환경
* GitHub Markdown Documentation

---

# 📑 추가 분석 및 트러블슈팅 회고

본 장에서는 실습 과정에서 확인한 현상을 기반으로 장애의 원인, Linux 명령어 활용 과정, 개선 방안 및 회고를 추가로 정리하였다.

---

# 1. GitHub Issue 작성 방식

본 프로젝트에서는 장애마다 다음과 같은 구조로 Issue를 작성하였다.

## Issue 구성

### 1. 현상 (Symptoms)

* 어떤 환경에서 문제가 발생했는가
* 어떤 로그가 출력되었는가
* 프로그램은 어떤 상태가 되었는가

### 2. 증거 (Evidence)

* 프로그램 로그
* monitor.sh 출력 결과
* top
* ps
* ps -L
* 스크린샷

### 3. 원인 분석 (Root Cause)

장애가 발생한 원인을 로그와 Linux 명령어를 기반으로 분석하였다.

### 4. 조치 (Action)

환경변수 변경

또는

코드 수정 방향을 제안하였다.

---

# 2. monitor.sh 분석

OOM 실험에서는 monitor.sh를 이용하여 Heap 사용량 변화를 지속적으로 관찰하였다.

monitor.sh는 일정 주기로 프로그램의 상태를 확인하며 메모리 사용량을 출력하도록 구성되어 있다.

대표적으로 다음과 같은 데이터를 지속적으로 수집한다.

* Heap Memory
* Memory Limit
* Memory Recovery 여부
* 프로세스 생존 여부

이를 통해 단순히 프로그램이 종료되었다는 사실이 아니라 **메모리가 어떤 패턴으로 증가했는지** 확인할 수 있었다.

---

# 3. top 명령어 활용

CPU 사용량을 확인하기 위해 Linux의 top 명령어를 사용하였다.

top에서는 다음과 같은 정보를 확인하였다.

* CPU 사용률(%CPU)
* 메모리 사용량(%MEM)
* 프로세스 상태
* PID
* 실행 시간

CPU_MAX_OCCUPY 값을 변경하면서 CPU 사용률이 증가하는 과정을 실시간으로 확인하였으며, CPU Threshold를 초과한 이후 Watchdog 정책이 SIGTERM을 발생시키는 과정을 로그와 함께 비교하였다.

---

# 4. ps와 ps -L을 사용한 분석 과정

Deadlock 발생 후 가장 먼저 프로세스가 살아있는지 확인하였다.

```bash
ps -ef | grep agent
```

프로세스가 종료되지 않았기 때문에 프로그램 자체는 살아 있으나 내부 작업이 멈춘 상태임을 확인하였다.

이후

```bash
ps -L -p PID
```

명령을 이용하여 Thread를 확인하였다.

여러 Worker Thread가 존재하고 있었으며, 프로그램은 종료되지 않았지만 Thread 간 자원 대기가 지속되고 있다는 점으로부터 Deadlock 가능성을 판단하였다.

---

# 5. OOM 발생 시 프로세스를 종료하는 이유

Memory Leak가 계속 발생하면 Heap 메모리는 지속적으로 증가한다.

메모리 사용량이 제한을 초과한 상태에서도 프로세스를 계속 실행하면 시스템 전체의 메모리를 고갈시킬 수 있다.

이를 방지하기 위해 MemoryGuard는 일정 임계치를 초과하면 해당 프로세스를 강제로 종료한다.

즉,

프로세스 하나를 종료함으로써 시스템 전체의 안정성을 보호하는 것이 목적이다.

---

# 6. 단일 프로세스를 종료하는 이유

Linux에서는 하나의 프로세스가 메모리를 독점하면 다른 프로세스도 정상적으로 실행되지 못한다.

따라서 문제가 발생한 프로세스만 종료하면

* 시스템 전체 다운 방지
* 다른 서비스 보호
* 리소스 회수

라는 효과를 얻을 수 있다.

---

# 7. Deadlock 발생 원리

Deadlock은 다음 네 가지 조건이 모두 만족할 때 발생한다.

* Mutual Exclusion (상호 배제)
* Hold and Wait
* No Preemption
* Circular Wait

이번 실습에서는 Thread-1과 Thread-2가 각각 서로 다른 자원을 먼저 점유한 뒤 상대 자원을 기다리는 상황이 발생하였다.

예를 들면

```
Thread-1
Shared_Memory_A 점유

↓

Socket_Pool_B 대기
```

```
Thread-2
Socket_Pool_B 점유

↓

Shared_Memory_A 대기
```

즉,

A → B

B → A

형태의 순환 대기(Circular Wait)가 형성되어 Deadlock이 발생하였다.

---

# 8. monitor.sh 개선 방안

현재 monitor.sh는 메모리 사용량만 확인하는 수준이다.

실제 운영 환경에서는 다음과 같은 기능을 추가하면 더욱 효과적이라고 생각하였다.

* Heap 증가 속도 계산
* 일정 시간 평균 메모리 사용량 출력
* 임계치 초과 시 Slack 또는 Email 알림
* 메모리 그래프 저장
* 로그 자동 백업

---

# 9. 가장 치명적인 장애

세 가지 장애 중 가장 치명적인 장애는 Memory Leak(OOM)이라고 판단하였다.

이유는 다음과 같다.

* 시간이 지날수록 반드시 악화된다.
* 서비스가 장시간 운영될수록 위험성이 증가한다.
* 시스템 전체 메모리 부족으로 이어질 수 있다.
* 결국 프로세스 종료 또는 시스템 장애를 유발한다.

CPU Spike는 일시적인 부하일 수 있고, Deadlock은 특정 기능에서만 발생할 수도 있지만 Memory Leak는 시간이 해결해 주지 않는 장애라는 점에서 가장 위험하다고 판단하였다.

---

# 10. OOM과 Deadlock이 동시에 발생한다면

우선순위는 다음과 같이 판단하였다.

① OOM 여부 확인

메모리 부족으로 프로세스가 종료되고 있는지 확인

↓

② 프로세스 생존 여부 확인

↓

③ Deadlock 분석

이유는 Deadlock 분석은 프로세스가 살아 있어야 가능하지만 OOM으로 종료되면 Thread 상태 자체를 확인할 수 없기 때문이다.

---

# 11. 코드 레벨 개선 방안

## Memory Leak

* 동적 메모리 해제
* Smart Pointer 사용
* 객체 생명주기 관리

---

## CPU Spike

* Busy Waiting 제거
* Sleep 적용
* 작업 큐 분산 처리
* Thread Pool 사용

---

## Deadlock

* Lock 획득 순서 통일
* Timeout Lock 적용
* Lock 범위 최소화
* 가능하면 Lock-Free 자료구조 사용

---

# 12. 프로젝트 회고

이번 프로젝트에서는 Linux 환경에서 발생하는 대표적인 시스템 장애를 직접 재현하고 분석하는 과정을 경험하였다.

처음에는 로그만 확인하는 수준이었지만, ps, ps -L, top 등의 Linux 명령어를 함께 활용하면서 장애 원인을 보다 체계적으로 추적하는 방법을 익힐 수 있었다.

또한 단순히 환경변수를 변경하여 장애를 회피하는 것이 아니라, 운영 환경에서는 코드 레벨의 개선과 지속적인 모니터링이 함께 이루어져야 근본적인 문제를 해결할 수 있다는 점을 이해하였다.

만약 동일한 프로젝트를 다시 수행한다면 monitor.sh 기능을 개선하여 메모리와 CPU 사용량을 자동으로 기록하고 그래프로 시각화하는 기능을 추가하고, GitHub Issue 역시 **현상 → 증거 → 원인 → 조치** 구조를 더욱 명확하게 작성하여 재현성과 가독성을 높일 것이다.

> **Note**
>
> 본 저장소는 Linux 기반 시스템 장애 분석 학습을 목적으로 작성된 프로젝트입니다.
> Memory Leak, CPU Spike, Deadlock을 직접 재현하고, 로그 및 Linux 명령어를 활용하여 원인을 분석한 과정을 기록하였습니다.
