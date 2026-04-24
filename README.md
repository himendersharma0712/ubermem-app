# ÜberMem v1.0 

**ÜberMem V1.0** is a high-performance, predictive kernel memory optimizer developed for Windows environments. Unlike traditional reactive memory cleaners, UberMem utilizes a **Temporal Pressure Forecasting (TPF)** engine and distilled Machine Learning (ML) logic to proactively stabilize system memory before performance degradation occurs.

---

## 🚀 Key Features

* **Auto Cleanup Mode:** A background monitoring loop that utilizes forecasting math to initiate memory purges before the system reaches critical saturation.
* **Deep Sweep (Kernel Actuation):** Direct interface with the Windows NT Executive via `NtSetSystemInformation` to flush the System File Cache, Modified Page List, and Standby Lists.
* **ML-Driven Process Triage:** Analyzes background processes using a weighted scoring engine (Memory, Pagefile, and Disk I/O) to identify and "squeeze" low-priority applications.
* **Temporal Forecasting:** Calculates **Pressure Velocity** ($V_p$) to predict system memory state 5 seconds into the future.
* **Industrial UI:** A sleek, low-luminance dashboard featuring real-time gauges, a 60-second temporal pressure graph, and a Live Diagnostics terminal.

---

## 🛠️ Tech Stack

* **Language:** C++20
* **Framework:** Qt 6.6 (QML/C++ Hybrid)
* **Toolchain:** MinGW
* **APIs:** Windows NTAPI (`ntdll.dll`), PSAPI, Win32
* **Logic:** Linear Regression & Distilled Decision Tree/Random Forest logic

---

## 🧠 System Logic

### Temporal Pressure Forecasting (TPF)
The Dispatcher calculates the predicted RAM usage using the current velocity ($V_p$) derived from a 60-second rolling buffer:

$$RAM_{predicted} = RAM_{current} + (V_p \times 5)$$

If the predicted value exceeds the defined threshold (e.g., 90%), a "Deep Sweep" is triggered immediately.

### ML Stability Index
Processes are evaluated based on weighted feature extraction:
* **Memory Weight:** 0.36
* **Pagefile Weight:** 0.37
* **Disk I/O Weight:** 0.27

---

## 🏗️ Installation & Build

### Prerequisites
* Windows 10/11 (Elevated Privileges Required)
* Qt 6.6+ with MinGW Toolchain
* Administrator rights are essential for `SE_PROF_SINGLE_PROCESS_NAME` token adjustments.

### Building
1.  Open the project in **Qt Creator**.
2.  Ensure the `app.manifest` and `resources.rc` are included in the build to force UAC elevation.
3.  Set the build profile to **Release**.
4.  Run as **Administrator**.

---

## 📁 Project Structure

* `main.cpp`: Application entry and QML context registration.
* `processModel.cpp/h`: Core optimization engine, ML triage, and NTAPI implementation.
* `SystemProvider.cpp/h`: Telemetry sensors, CPU/RAM monitoring, and velocity calculations.
* `Main.qml`: Dashboard interface and visualization logic.
* `processData.h`: Data structures for process telemetry.

---

## ⚠️ Disclaimer

ÜberMem v1.0 interfaces directly with the Windows Kernel. Improper use or modification of kernel-level actuation calls (`NtSetSystemInformation`) can lead to system instability. This utility is intended for high-performance and educational environments.

