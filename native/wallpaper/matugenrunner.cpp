#include "matugenrunner.h"
#include "processscheduler.h"

#include <QStringList>

namespace {

constexpr int backgroundNiceLevel = 10;

} // namespace

MatugenRunner::MatugenRunner(QObject *parent)
    : QObject(parent)
{
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
    Ateria::setBackgroundScheduling(m_process, true, backgroundNiceLevel);

    connect(&m_process, &QProcess::stateChanged, this, [this] {
        updateRunning();
    });
    connect(&m_process, &QProcess::readyReadStandardOutput,
            this, &MatugenRunner::collectStandardOutput);
    connect(&m_process, &QProcess::readyReadStandardError,
            this, &MatugenRunner::collectStandardError);
    connect(&m_process, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus) {
                finish(exitCode);
            });
    connect(&m_process, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
                if (error != QProcess::FailedToStart || !m_active)
                    return;

                m_standardError.append(m_process.errorString().toUtf8());
                finish(-1);
            });
}

bool MatugenRunner::running() const
{
    return m_running;
}

bool MatugenRunner::generate(const QString &program,
                             const QString &imagePath,
                             const QString &configPath,
                             const QString &requestId)
{
    if (m_active || program.isEmpty() || imagePath.isEmpty()
        || configPath.isEmpty() || requestId.isEmpty()) {
        return false;
    }

    m_requestId = requestId;
    m_standardOutput.clear();
    m_standardError.clear();
    m_active = true;

    m_process.setProgram(program);
    m_process.setArguments({QStringLiteral("image"),
                            imagePath,
                            QStringLiteral("--config"),
                            configPath,
                            QStringLiteral("--source-color-index"),
                            QStringLiteral("0"),
                            QStringLiteral("--json"),
                            QStringLiteral("hex"),
                            QStringLiteral("--quiet")});
    m_process.start();
    updateRunning();
    return true;
}

void MatugenRunner::updateRunning()
{
    const bool runningNow = m_process.state() != QProcess::NotRunning;
    if (m_running == runningNow)
        return;

    m_running = runningNow;
    emit runningChanged();
}

void MatugenRunner::collectStandardOutput()
{
    const QByteArray output = m_process.readAllStandardOutput();
    if (output.isEmpty())
        return;

    m_standardOutput.append(output);
    emit outputAvailable(m_requestId, QString::fromUtf8(m_standardOutput));
}

void MatugenRunner::collectStandardError()
{
    m_standardError.append(m_process.readAllStandardError());
}

void MatugenRunner::finish(int exitCode)
{
    if (!m_active)
        return;

    collectStandardOutput();
    collectStandardError();

    const QString requestId = m_requestId;
    const QString standardOutput = QString::fromUtf8(m_standardOutput);
    const QString standardError = QString::fromUtf8(m_standardError);
    m_active = false;
    m_requestId.clear();
    updateRunning();
    emit finished(requestId, exitCode, standardOutput, standardError);
}
