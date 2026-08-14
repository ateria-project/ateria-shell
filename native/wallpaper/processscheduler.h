#pragma once

class QProcess;

namespace Ateria {

void setBackgroundScheduling(QProcess &process, bool enabled, int niceLevel);

} // namespace Ateria
