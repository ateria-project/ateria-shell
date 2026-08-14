#pragma once

#include <QByteArray>
#include <QObject>
#include <QProcess>
#include <QString>
#include <QtQmlIntegration>

class MatugenRunner : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    explicit MatugenRunner(QObject *parent = nullptr);

    bool running() const;

    Q_INVOKABLE bool generate(const QString &program,
                              const QString &imagePath,
                              const QString &configPath,
                              const QString &requestId);

signals:
    void runningChanged();
    void outputAvailable(const QString &requestId, const QString &standardOutput);
    void finished(const QString &requestId,
                  int exitCode,
                  const QString &standardOutput,
                  const QString &standardError);

private:
    void updateRunning();
    void collectStandardOutput();
    void collectStandardError();
    void finish(int exitCode);

    QProcess m_process;
    QString m_requestId;
    QByteArray m_standardOutput;
    QByteArray m_standardError;
    bool m_running = false;
    bool m_active = false;
};
