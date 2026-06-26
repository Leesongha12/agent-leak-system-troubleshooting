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

> **Note**
>
> 본 저장소는 Linux 기반 시스템 장애 분석 학습을 목적으로 작성된 프로젝트입니다.
> Memory Leak, CPU Spike, Deadlock을 직접 재현하고, 로그 및 Linux 명령어를 활용하여 원인을 분석한 과정을 기록하였습니다.



# agent-leak-system-troubleshooting
Memory Leak, CPU Spike, Deadlock troubleshooting report for agent-leak-app
# Agent Leak App System Troubleshooting Report

## 프로젝트 개요

본 저장소는 **agent-leak-app**을 대상으로 Linux 환경에서 발생하는 대표적인 시스템 장애를 분석한 트러블슈팅 결과를 정리한 저장소입니다.

본 프로젝트에서는 단순히 프로그램 실행 결과를 확인하는 것이 아니라 운영 환경에서 수집 가능한 로그와 시스템 명령어를 기반으로 장애의 원인을 분석하고, GitHub Issue 형태의 기술 리포트를 작성하는 것을 목표로 하였습니다.

---

# 분석 대상

본 프로젝트에서는 다음 세 가지 장애를 분석하였습니다.

* Memory Leak (OOM)
* CPU Spike (CPU Occupancy)
* Deadlock

---

# 개발 환경

| 항목       | 내용                  |
| -------- | ------------------- |
| OS       | Ubuntu 22.04 (WSL2) |
| Terminal | Ubuntu (WSL)        |
| 실행 파일    | agent-leak-app-x86  |
| 사용자      | 일반 계정 (songha)      |

---

# 프로젝트 구조

```
agent/
├── api_keys/
│   └── secret.key
├── logs/
├── upload_files/
└── agent-leak-app-x86
```

---

# 사전 환경 구성

필수 디렉터리 생성

```bash
mkdir -p ~/agent/logs
mkdir -p ~/agent/upload_files
mkdir -p ~/agent/api_keys
```

secret.key 생성

```bash
echo "agent_api_key_test" > ~/agent/api_keys/secret.key
```

---

# 환경 변수 설정

```bash
export AGENT_HOME=$HOME/agent
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=$AGENT_HOME/logs
```

---

# OOM(Memory Leak) 실험

### Before

```bash
export MEMORY_LIMIT=256
export CPU_MAX_OCCUPY=50
export MULTI_THREAD_ENABLE=true
```

실행

```bash
./agent-leak-app-x86
```

확인 결과

* Heap 메모리가 지속적으로 증가
* 275MB에서 MemoryGuard가 동작
* SELF-TERMINATED 발생

주요 로그

```
Current Heap: 25MB
Current Heap: 50MB
Current Heap: 75MB
...
Current Heap: 275MB

Memory limit exceeded (275MB >= 256MB)

SELF-TERMINATED
```

---

### After

```bash
export MEMORY_LIMIT=512
export MULTI_THREAD_ENABLE=false
```

실행 결과

* Heap 증가
* Memory Cache Flushed
* MEMORY RECOVERED
* 종료되지 않고 정상 유지

결론

* MEMORY_LIMIT 증가 시 생존 시간이 증가함
* 메모리 증가 패턴 자체는 계속 발생
* 근본 원인은 Memory Leak

---

# CPU Spike 실험

### Before

```bash
export CPU_MAX_OCCUPY=10
```

확인 로그

```
Current Load : 5%

Current Load : 8%

Current Load : 10%

Peak reached (10%)

Starting cooldown
```

결과

CPU 사용량이 10%에 도달하면 Cooldown 수행

---

### After

```bash
export CPU_MAX_OCCUPY=100
```

확인 로그

```
Current Load : 5%

Current Load : 6%

Current Load : 10%

Current Load : 15%

Current Load : 16%
```

결과

CPU 사용량이 지속적으로 증가

10%에서 제한되지 않음

---

# Deadlock 실험

환경

```bash
export MULTI_THREAD_ENABLE=true
```

실행 결과

```
Worker-Thread-1

LOCK ACQUIRED

Worker-Thread-2

LOCK ACQUIRED

WAITING

BLOCKED
```

확인 명령어

```bash
ps -ef | grep agent
```

결과

```
1818
1819
```

스레드 확인

```bash
ps -L -p 1819
```

결과

```
1819

1820

1821
```

분석

* Thread1이 Shared_Memory_A를 점유
* Thread2가 Socket_Pool_B를 점유
* 서로 상대 자원을 기다리며 교착상태 발생

---

# 사용한 Linux 명령어

프로세스 확인

```bash
ps -ef | grep agent
```

스레드 확인

```bash
ps -L -p PID
```

CPU 확인

```bash
top
```

프로세스 종료

```bash
kill PID
```

---

# 작성한 GitHub Issues

* Issue #1 OOM Crash 분석
* Issue #2 CPU Spike 분석
* Issue #3 Deadlock 분석

---

# 프로젝트를 통해 학습한 내용

* Linux 환경변수 구성
* 프로세스 및 스레드 관리
* 메모리 누수 분석
* CPU 사용량 모니터링
* 교착상태(Deadlock) 원인 분석
* GitHub Issue 기반 장애 리포트 작성

  # 프로젝트 구조

```text
agent/
├── api_keys/
│   └── secret.key
├── logs/
├── upload_files/
└── agent-leak-app-x86
```

### 📷 프로젝트 구조

![Project Structure](screenshots/setup/01_screenshot_folders.png)

---

# 사전 환경 구성

필수 디렉터리 생성

```bash
mkdir -p ~/agent/logs
mkdir -p ~/agent/upload_files
mkdir -p ~/agent/api_keys
```

secret.key 생성

```bash
echo "agent_api_key_test" > ~/agent/api_keys/secret.key
```

### 📷 실행 파일 확인

![Application Files](screenshots/setup/02_app_files.png)

---

# 환경 변수 설정

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

![Environment Variables](screenshots/setup/03_environment_variables.png)

---

# Boot Success

프로그램이 정상적으로 Boot Sequence를 통과한 화면입니다.

![Boot Success](screenshots/setup/04_boot_success.png)

---

# OOM (Memory Leak) 실험

## Before

```bash
export MEMORY_LIMIT=256
export CPU_MAX_OCCUPY=50
export MULTI_THREAD_ENABLE=true

./agent-leak-app-x86
```

### 확인 결과

* Heap 메모리가 지속적으로 증가
* 275MB에서 MemoryGuard 동작
* SELF-TERMINATED 발생

주요 로그

```
Current Heap: 25MB
Current Heap: 50MB
Current Heap: 75MB
...
Current Heap: 275MB

Memory limit exceeded (275MB >= 256MB)

SELF-TERMINATED
```

### 📷 OOM 종료 직전 로그

![OOM Before](screenshots/oom/01_oom_before_self_terminated.png)

---

### 📷 monitor.sh 관제 결과

![OOM Monitor](screenshots/oom/02_oom_monitor.png)

---

## After

```bash
export MEMORY_LIMIT=512
export MULTI_THREAD_ENABLE=false
```

실행 결과

* Heap 증가
* Memory Cache Flushed
* MEMORY RECOVERED
* 종료되지 않고 정상 유지

### 📷 MEMORY_LIMIT=512 실행 결과

![OOM After](screenshots/oom/03_after_512mb.png)

---

### 결론

* MEMORY_LIMIT 증가 시 생존 시간이 증가함
* 메모리 증가 패턴 자체는 계속 발생
* 근본 원인은 Memory Leak

---

# CPU Spike 실험

## Before

```bash
export CPU_MAX_OCCUPY=10
```

확인 로그

```
Current Load : 5%
Current Load : 8%
Current Load : 10%
Peak reached (10%)
Starting cooldown
```

### 📷 CPU Cooldown

![CPU Cooldown](screenshots/cpu/01_cpu_cooldown.png)

---

### 📷 top 명령어 확인

![Top CPU](screenshots/cpu/02_top_cpu.png)

---

## After

```bash
export CPU_MAX_OCCUPY=100
```

확인 로그

```
Current Load : 44%

Current Load : 54%

CPU Threshold Violated!

WATCHDOG

SIGTERM
```

### 📷 Watchdog 종료

![Watchdog SIGTERM](screenshots/cpu/03_watchdog_sigterm.png)

---

### 결과

* CPU_MAX_OCCUPY=10에서는 10% 도달 시 Cooldown 수행
* CPU_MAX_OCCUPY=100에서는 CPU 사용량이 지속 증가
* Watchdog 정책이 SIGTERM으로 프로세스를 종료

---

# Deadlock 실험

## 환경

```bash
export MULTI_THREAD_ENABLE=true
```

실행 결과

```
Worker-Thread-1

LOCK ACQUIRED

Worker-Thread-2

LOCK ACQUIRED

WAITING

BLOCKED
```

### 📷 WAITING / BLOCKED

![Deadlock Blocked](screenshots/deadlock/01_blocked_log.png)

---

확인 명령어

```bash
ps -ef | grep agent
```

### 📷 PID 존재 확인

![PID Alive](screenshots/deadlock/02_pid_alive.png)

---

스레드 확인

```bash
ps -L -p PID
```

### 📷 Thread 상태

![Thread State](screenshots/deadlock/03_thread_state.png)

---

## Deadlock 해결

```bash
export MULTI_THREAD_ENABLE=false
```

### 📷 Deadlock 해결

![Deadlock Resolved](screenshots/deadlock/04_deadlock_resolved.png)

---

(선택) 프로세스 종료 확인

### 📷 Process 종료

![Process Killed](screenshots/deadlock/04_process_killed.png)

---

### 분석

* Thread-1이 Shared_Memory_A를 점유
* Thread-2가 Socket_Pool_B를 점유
* 두 스레드가 서로 상대 자원을 기다리며 순환 대기(Circular Wait)가 발생
* MULTI_THREAD_ENABLE=false 설정 후 Deadlock 없이 정상 수행됨


---

# 참고

본 저장소는 운영 환경에서 발생 가능한 시스템 장애를 Linux 명령어와 프로그램 로그를 기반으로 분석한 학습 프로젝트입니다.
