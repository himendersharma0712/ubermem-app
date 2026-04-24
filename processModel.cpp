#include "processModel.h"
#include <windows.h>
#include <psapi.h>
#include <QTimer>
#include <algorithm>
#include <QDateTime>
#include <QDebug>



typedef struct _SYSTEM_FILECACHE_INFORMATION {
    SIZE_T CurrentSize;
    SIZE_T PeakSize;
    SIZE_T PageFaultCount;
    SIZE_T MinimumWorkingSet;
    SIZE_T MaximumWorkingSet;
    SIZE_T CurrentSizeIncludingTransitionInPages;
    SIZE_T PeakSizeIncludingTransitionInPages;
    ULONG TransitionRePurposeCount;
    ULONG Flags;
} SYSTEM_FILECACHE_INFORMATION;


// --- NTAPI Definitions for Deep Sweep ---
typedef enum _SYSTEM_MEMORY_LIST_COMMAND {
    MemoryEmptyWorkingSets = 2,
    MemoryFlushModifiedList = 3,
    MemoryPurgeStandbyList = 4,
    MemoryPurgeLowPriorityStandbyList = 5
} SYSTEM_MEMORY_LIST_COMMAND;

typedef NTSTATUS(WINAPI *pNtSetSystemInformation)(
    INT SystemInformationClass,
    PVOID SystemInformation,
    ULONG SystemInformationLength
    );

// --- Privilege Escalation Helper ---
bool EnablePrivilege() {
    HANDLE hToken;
    TOKEN_PRIVILEGES tp;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) return false;

    // Use the Name string, not the integer ID
    if (!LookupPrivilegeValue(NULL, SE_PROF_SINGLE_PROCESS_NAME, &tp.Privileges[0].Luid)) {
        CloseHandle(hToken);
        return false;
    }

    tp.PrivilegeCount = 1;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;

    // Adjust and check for partial success
    bool result = AdjustTokenPrivileges(hToken, FALSE, &tp, 0, NULL, 0);
    if (GetLastError() == ERROR_NOT_ALL_ASSIGNED) result = false;

    CloseHandle(hToken);
    return result;
}





ProcessModel::ProcessModel(QObject *parent) : QAbstractTableModel(parent) {
    refreshProcesses();
    QTimer *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &ProcessModel::refreshProcesses);
    timer->start(500); // 500ms Real-time refresh
}

int ProcessModel::rowCount(const QModelIndex &parent) const { return m_processes.size(); }

// 8 Columns to match the UI
int ProcessModel::columnCount(const QModelIndex &parent) const { return 8; }

QHash<int, QByteArray> ProcessModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[PidRole] = "pid";
    roles[StatusRole] = "status";
    roles[CpuRole] = "cpu";
    roles[MemRole] = "mem";
    roles[RawMemRole] = "rawMem";
    roles[DiskRole] = "disk";
    roles[PagefileRole] = "pagefile";
    roles[PredictionRole] = "prediction";
    return roles;
}

QVariant ProcessModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_processes.size()) return QVariant();
    const auto &process = m_processes[index.row()];

    switch (role) {
    case NameRole:     return process.name;
    case PidRole:      return (int)process.pid;
    case StatusRole:   return process.status;
    case CpuRole:      return "0.0%"; // Placeholder for now to avoid nan%
    case MemRole:      return QString::number(process.memUsage, 'f', 1) + " MB";
    case RawMemRole:   return process.memUsage;
    case DiskRole:     return QString::number(process.diskUsage, 'f', 1) + " KB/s";
    case PagefileRole: return QString::number(process.pagefileUsage, 'f', 1) + " MB";
    case PredictionRole: return (process.importanceScore > 0.7) ? "STABLE" : "RISK";
    default:           return QVariant();
    }
}

void ProcessModel::refreshProcesses() {
    // 1. Get fresh PIDs from Windows
    DWORD aProcesses[1024], cbNeeded;
    if (!EnumProcesses(aProcesses, sizeof(aProcesses), &cbNeeded)) return;
    int cProcesses = cbNeeded / sizeof(DWORD);
    DWORD dwForegroundPid;
    GetWindowThreadProcessId(GetForegroundWindow(), &dwForegroundPid);

    // 2. Build the CLEAN sorted list in a temporary buffer
    QVector<ProcessInfo> nextGen;
    for (unsigned int i = 0; i < (unsigned int)cProcesses; i++) {
        if (aProcesses[i] == 0) continue;

        HANDLE hP = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, aProcesses[i]);
        if (hP) {
            TCHAR szName[MAX_PATH] = TEXT("<unknown>");
            HMODULE hMod; DWORD cbMod;
            if (EnumProcessModules(hP, &hMod, sizeof(hMod), &cbMod))
                GetModuleBaseName(hP, hMod, szName, sizeof(szName)/sizeof(TCHAR));

            PROCESS_MEMORY_COUNTERS_EX pmc;
            if (GetProcessMemoryInfo(hP, (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
                ProcessInfo info;
                info.pid = aProcesses[i];
                info.name = QString::fromWCharArray(szName);
                info.memUsage = pmc.WorkingSetSize / 1048576.0; // MB
                info.pagefileUsage = pmc.PrivateUsage / 1048576.0;
                info.status = (info.pid == dwForegroundPid) ? "Foreground" : "Background";

                // Extract Disk I/O before ML logic
                info.diskUsage = 0.0;
                IO_COUNTERS io;
                if (GetProcessIoCounters(hP, &io)) {
                    info.diskUsage = (io.ReadTransferCount + io.WriteTransferCount) / 1024.0;
                }


                const double MEM_WEIGHT = 0.36;
                const double PAGE_WEIGHT = 0.37;
                const double DISK_WEIGHT = 0.27;

                double interest = (info.memUsage / 1024.0) * MEM_WEIGHT +
                                  (info.pagefileUsage / 2048.0) * PAGE_WEIGHT +
                                  (info.diskUsage / 500000.0) * DISK_WEIGHT;

                if (info.status == "Foreground") {
                    info.importanceScore = 0.95; // Absolute Priority
                }
                else if (m_isGamingMode) {
                    const double GAME_MIN_RAM = 400.0; // 99th percentile of background noise
                    const double MAX_BACKGROUND_PAGEFILE = 350.0;
                    const double MAX_BACKGROUND_DISK = 3000000.0; // 3GB tolerance before marking as risk

                    if (info.memUsage > GAME_MIN_RAM) {

                        info.importanceScore = 0.75 + (interest * 0.1);
                        if (info.importanceScore > 0.89) info.importanceScore = 0.89;
                    }
                    else if (info.pagefileUsage > MAX_BACKGROUND_PAGEFILE || info.diskUsage > MAX_BACKGROUND_DISK) {

                        info.importanceScore = 0.05;
                    }
                    else {

                        info.importanceScore = 0.15;
                    }
                }
                else {

                    const double STUDY_MIN_RAM = 77.15;
                    const double STUDY_MAX_DISK = 233151.56;

                    if (info.memUsage > STUDY_MIN_RAM && info.diskUsage < STUDY_MAX_DISK) {

                        info.importanceScore = 0.70 + (interest * 0.2);
                        if (info.importanceScore > 0.89) info.importanceScore = 0.89;
                    }
                    else {

                        info.importanceScore = 0.20 + (interest * 0.1);
                    }
                }

                info.cpuUsage = 0.0;
                nextGen.append(info);
            }
            CloseHandle(hP);
        }
    }


    std::sort(nextGen.begin(), nextGen.end(), [](const ProcessInfo& a, const ProcessInfo& b) {
        return a.memUsage > b.memUsage;
    });


    int nextSize = nextGen.size();
    int currentSize = m_processes.size();

    if (nextSize > currentSize) {
        beginInsertRows(QModelIndex(), currentSize, nextSize - 1);
        m_processes = nextGen;
        endInsertRows();
    } else if (nextSize < currentSize) {
        beginRemoveRows(QModelIndex(), nextSize, currentSize - 1);
        m_processes = nextGen;
        endRemoveRows();
    } else {
        m_processes = nextGen;
    }


    if (!m_processes.isEmpty()) {
        emit dataChanged(index(0, 0), index(m_processes.size() - 1, 7));
    }



    if (m_autoMode) {
        qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

        if (currentTime - m_lastAutoPurge > 15000) { // 15s cooldown
            MEMORYSTATUSEX memInfo;
            memInfo.dwLength = sizeof(MEMORYSTATUSEX);

            if (GlobalMemoryStatusEx(&memInfo)) {
                // 1. GET THE ML INPUTS
                double currentRAM = (double)memInfo.dwMemoryLoad;

                // We'll need a way to access SystemProvider's velocity here
                // For now, let's assume you pass it or use a singleton
                double velocity = m_currentVelocity;

                // 2. THE FORECAST (Predicting 5 seconds ahead)
                double predictedRAM = currentRAM + (velocity * 5.0);

                // 3. THE ML TRIGGER
                // Trigger if we predict > 90% OR if we are currently > 85%
                if (predictedRAM > 80.0 || currentRAM > 75.0) {
                    m_lastAutoPurge = currentTime;
                    qDebug() << "[SENTINEL] ML Forecast: Critical Pressure Predicted ("
                             << predictedRAM << "%). Executing Purge.";
                    purgeRiskProcesses();
                }
            }
        }
    }
}



void ProcessModel::purgeRiskProcesses() {
    // 1. THE IMMUNE SYSTEM (Absolute protection to prevent UI lag)
    QStringList systemEssential = {
        "explorer.exe", "SearchHost.exe", "StartMenuExperienceHost.exe",
        "ShellExperienceHost.exe", "sihost.exe", "taskhostw.exe",
        "TextInputHost.exe", "ctfmon.exe", "dwm.exe", "svchost.exe"
    };

    int optimizedCount = 0;

    // --- PHASE 1: Working Set Trimming ---
    for (const auto& process : m_processes) {
        // Foreground app is 100% immune
        if (process.status == "Foreground") continue;

        // Skip absolute core UI components to maintain responsiveness
        if (systemEssential.contains(process.name, Qt::CaseInsensitive)) continue;

        // Open process for memory management
        HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA, FALSE, process.pid);

        if (hProcess != NULL) {
            double aggressiveThreshold = m_isGamingMode ? 0.98 : 0.85;

            if (process.importanceScore < aggressiveThreshold) {
                // Strip the working set
                if (SetProcessWorkingSetSize(hProcess, (SIZE_T)-1, (SIZE_T)-1)) {
                    optimizedCount++;
                }
            }
            CloseHandle(hProcess);
        }
    }


    if (m_isGamingMode) {
        if (EnablePrivilege()) {
            HMODULE hNtDll = GetModuleHandleA("ntdll.dll");
            pNtSetSystemInformation NtSetSystemInformation = (pNtSetSystemInformation)GetProcAddress(hNtDll, "NtSetSystemInformation");

            if (NtSetSystemInformation) {
                // --- VAULT 1: SYSTEM FILE CACHE ---
                SYSTEM_FILECACHE_INFORMATION sfci;
                ZeroMemory(&sfci, sizeof(sfci));
                sfci.MinimumWorkingSet = (SIZE_T)-1; // The "Force" command
                sfci.MaximumWorkingSet = (SIZE_T)-1;
                NtSetSystemInformation(21, &sfci, sizeof(sfci)); // 21 = SystemFileCacheInformation

                // --- VAULT 2: STANDBY LISTS ---
                SYSTEM_MEMORY_LIST_COMMAND command;
                command = MemoryPurgeLowPriorityStandbyList;
                NtSetSystemInformation(80, &command, sizeof(command));
                command = MemoryPurgeStandbyList;
                NtSetSystemInformation(80, &command, sizeof(command));
            }
        }
    }

    refreshProcesses(); // Trigger UI update
}


