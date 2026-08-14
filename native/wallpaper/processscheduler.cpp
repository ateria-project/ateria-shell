#include "processscheduler.h"

#include <QProcess>

#if defined(Q_OS_LINUX)
#include <linux/ioprio.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <unistd.h>
#endif

namespace Ateria {

void setBackgroundScheduling(QProcess &process, bool enabled, int niceLevel)
{
#if defined(Q_OS_LINUX)
    if (!enabled) {
        process.setChildProcessModifier({});
        return;
    }

    process.setChildProcessModifier([niceLevel] {
        // Descendants inherit these priorities. Failures are non-fatal on
        // kernels or filesystems that do not implement I/O priorities.
        (void)setpriority(PRIO_PROCESS, 0, niceLevel);
        constexpr int idleIoPriority = IOPRIO_CLASS_IDLE << IOPRIO_CLASS_SHIFT;
        (void)syscall(SYS_ioprio_set, IOPRIO_WHO_PROCESS, 0, idleIoPriority);
    });
#else
    Q_UNUSED(process);
    Q_UNUSED(enabled);
    Q_UNUSED(niceLevel);
#endif
}

} // namespace Ateria
