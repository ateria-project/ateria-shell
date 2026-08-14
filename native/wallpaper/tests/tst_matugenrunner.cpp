#include "matugenrunner.h"

#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

namespace {

QString createProgram(const QString &directory, const QByteArray &body)
{
    const QString path = directory + QStringLiteral("/fake-matugen");
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return {};
    file.write("#!/bin/sh\n");
    file.write(body);
    file.close();
    if (!file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner
                             | QFileDevice::ExeOwner)) {
        return {};
    }
    return path;
}

} // namespace

class MatugenRunnerTest : public QObject
{
    Q_OBJECT

private slots:
    void streamsOutputBeforeReloadWorkFinishes();
    void appliesBackgroundCpuPriority();
};

void MatugenRunnerTest::streamsOutputBeforeReloadWorkFinishes()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString program = createProgram(
        directory.path(),
        "printf '{\"colors\":{}}\\n'\n"
        "sleep 0.2\n");
    QVERIFY(!program.isEmpty());

    MatugenRunner runner;
    QSignalSpy outputSpy(&runner, &MatugenRunner::outputAvailable);
    QSignalSpy finishedSpy(&runner, &MatugenRunner::finished);

    QVERIFY(runner.generate(program,
                            QStringLiteral("/tmp/wallpaper.png"),
                            QStringLiteral("/tmp/matugen.toml"),
                            QStringLiteral("wallpaper-request")));
    QTRY_VERIFY_WITH_TIMEOUT(!outputSpy.isEmpty(), 1000);
    QVERIFY(runner.running());
    QCOMPARE(outputSpy.constFirst().at(0).toString(), QStringLiteral("wallpaper-request"));
    QVERIFY(outputSpy.constFirst().at(1).toString().contains(QStringLiteral("\"colors\"")));

    QTRY_COMPARE_WITH_TIMEOUT(finishedSpy.size(), 1, 2000);
    QCOMPARE(finishedSpy.constFirst().at(0).toString(), QStringLiteral("wallpaper-request"));
    QCOMPARE(finishedSpy.constFirst().at(1).toInt(), 0);
    QVERIFY(!runner.running());
}

void MatugenRunnerTest::appliesBackgroundCpuPriority()
{
#if defined(Q_OS_LINUX)
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString program = createProgram(
        directory.path(),
        "awk '{print $19}' /proc/self/stat\n");
    QVERIFY(!program.isEmpty());

    MatugenRunner runner;
    QSignalSpy finishedSpy(&runner, &MatugenRunner::finished);
    QVERIFY(runner.generate(program,
                            QStringLiteral("/tmp/wallpaper.png"),
                            QStringLiteral("/tmp/matugen.toml"),
                            QStringLiteral("priority-request")));

    QTRY_COMPARE_WITH_TIMEOUT(finishedSpy.size(), 1, 2000);
    QCOMPARE(finishedSpy.constFirst().at(1).toInt(), 0);
    QVERIFY(finishedSpy.constFirst().at(2).toString().trimmed().toInt() >= 10);
#else
    QSKIP("Linux scheduling policy test");
#endif
}

QTEST_GUILESS_MAIN(MatugenRunnerTest)

#include "tst_matugenrunner.moc"
