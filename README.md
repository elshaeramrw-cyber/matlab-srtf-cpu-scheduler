# Preemptive SRTF CPU Scheduling Simulator

An object-oriented **Shortest Remaining Time First (SRTF)** preemptive CPU scheduling simulator written in MATLAB, complete with spreadsheet workload I/O and timeline visualization.

## 📂 Repository Structure

| File | Role | Description |
| :--- | :--- | :--- |
| `SRTF_Scheduler.m` | **Scheduler Class (OOP)** | Implements dynamic arrival queue handling, preemption logic, FCFS tie-breaking, and calculation of waiting, turnaround, response times, and CPU utilization. |
| `run_srtf_demo.m` | **Simulation Runner & Plotting** | Reads process workloads from Excel (`readtable`), runs the SRTF scheduler, exports metrics (`writetable`), and generates Gantt chart visualizations. |

## 🛠️ Tech Stack
* **Language & Tools:** MATLAB (Object-Oriented Programming, Table / Excel I/O)
