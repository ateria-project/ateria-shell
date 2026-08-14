#include "niriipc.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <memory>

class ScopedEnvironmentVariable
{
public:
    ScopedEnvironmentVariable(const char *name, const QByteArray &value)
        : m_name(name)
        , m_wasSet(qEnvironmentVariableIsSet(name))
        , m_previous(qgetenv(name))
    {
        qputenv(m_name.constData(), value);
    }

    ~ScopedEnvironmentVariable()
    {
        if (m_wasSet)
            qputenv(m_name.constData(), m_previous);
        else
            qunsetenv(m_name.constData());
    }

private:
    QByteArray m_name;
    bool m_wasSet;
    QByteArray m_previous;
};

class NiriIpcTest : public QObject
{
    Q_OBJECT

private slots:
    void receivesEventStream();
    void sendsFocusWindowAction();
    void serializesCrossOutputWorkspaceFocus();
    void rejectsInvalidOrUnavailableActions();
};

void NiriIpcTest::receivesEventStream()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString socketPath = directory.filePath(QStringLiteral("niri.sock"));
    ScopedEnvironmentVariable environment("NIRI_SOCKET", socketPath.toUtf8());

    QLocalServer server;
    QVERIFY(server.listen(socketPath));

    QByteArray request;
    QLocalSocket *peer = nullptr;
    QObject::connect(&server, &QLocalServer::newConnection, &server, [&] {
        peer = server.nextPendingConnection();
        QObject::connect(peer, &QLocalSocket::readyRead, &server, [&] {
            request.append(peer->readAll());
            if (!request.contains('\n'))
                return;
            peer->write(QByteArrayLiteral("{\"Ok\":\"Handled\"}\n"));
            peer->write(QByteArrayLiteral("not-json\n"));
            peer->write(QByteArrayLiteral(
                "{\"WorkspacesChanged\":{\"workspaces\":[{\"id\":7,\"idx\":1}]}}\n"));
            peer->flush();
        });
    });

    NiriIpc ipc;
    QSignalSpy connectedSpy(&ipc, &NiriIpc::connectedChanged);
    QSignalSpy parseFailedSpy(&ipc, &NiriIpc::eventParseFailed);
    QSignalSpy eventSpy(&ipc, &NiriIpc::eventReceived);
    ipc.initialize();

    QTRY_COMPARE_WITH_TIMEOUT(eventSpy.count(), 1, 2000);
    QCOMPARE(request, QByteArrayLiteral("\"EventStream\"\n"));
    QVERIFY(ipc.connected());
    QVERIFY(ipc.available());
    QVERIFY(!connectedSpy.isEmpty());
    QCOMPARE(parseFailedSpy.count(), 1);
    QVERIFY(ipc.lastError().isEmpty());
    const QVariantMap event = eventSpy.constFirst().constFirst().toMap();
    QVERIFY(event.contains(QStringLiteral("WorkspacesChanged")));
}

void NiriIpcTest::sendsFocusWindowAction()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString socketPath = directory.filePath(QStringLiteral("niri.sock"));
    ScopedEnvironmentVariable environment("NIRI_SOCKET", socketPath.toUtf8());

    QLocalServer server;
    QVERIFY(server.listen(socketPath));
    QByteArray request;
    QObject::connect(&server, &QLocalServer::newConnection, &server, [&] {
        QLocalSocket *peer = server.nextPendingConnection();
        QObject::connect(peer, &QLocalSocket::readyRead, &server, [&, peer] {
            request.append(peer->readAll());
            if (!request.contains('\n'))
                return;
            peer->write(QByteArrayLiteral("{\"Ok\":\"Handled\"}\n"));
            peer->flush();
        });
    });

    NiriIpc ipc;
    QSignalSpy completedSpy(&ipc, &NiriIpc::actionCompleted);
    QVERIFY(ipc.focusWindow(42));
    QTRY_COMPARE_WITH_TIMEOUT(completedSpy.count(), 1, 2000);
    QCOMPARE(request,
             QByteArrayLiteral("{\"Action\":{\"FocusWindow\":{\"id\":42}}}\n"));
    QCOMPARE(completedSpy.constFirst().constFirst().toString(), QStringLiteral("focus-window"));
}

void NiriIpcTest::serializesCrossOutputWorkspaceFocus()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString socketPath = directory.filePath(QStringLiteral("niri.sock"));
    ScopedEnvironmentVariable environment("NIRI_SOCKET", socketPath.toUtf8());

    QLocalServer server;
    QVERIFY(server.listen(socketPath));
    QList<QByteArray> requests;
    QObject::connect(&server, &QLocalServer::newConnection, &server, [&] {
        QLocalSocket *peer = server.nextPendingConnection();
        auto buffer = std::make_shared<QByteArray>();
        QObject::connect(peer, &QLocalSocket::readyRead, &server, [&, peer, buffer] {
            buffer->append(peer->readAll());
            if (!buffer->contains('\n'))
                return;
            requests.append(*buffer);
            peer->write(QByteArrayLiteral("{\"Ok\":\"Handled\"}\n"));
            peer->flush();
        });
    });

    NiriIpc ipc;
    QSignalSpy completedSpy(&ipc, &NiriIpc::actionCompleted);
    QVERIFY(ipc.focusWorkspace(2, QStringLiteral("eDP-1"), QStringLiteral("DP-1")));
    QTRY_COMPARE_WITH_TIMEOUT(completedSpy.count(), 2, 2000);
    QCOMPARE(requests.size(), 2);
    QCOMPARE(requests.at(0),
             QByteArrayLiteral("{\"Action\":{\"FocusMonitor\":{\"output\":\"eDP-1\"}}}\n"));
    QCOMPARE(requests.at(1),
             QByteArrayLiteral(
                 "{\"Action\":{\"FocusWorkspace\":{\"reference\":{\"Index\":2}}}}\n"));
}

void NiriIpcTest::rejectsInvalidOrUnavailableActions()
{
    ScopedEnvironmentVariable environment("NIRI_SOCKET", QByteArray());
    NiriIpc ipc;
    QSignalSpy failedSpy(&ipc, &NiriIpc::actionFailed);

    QVERIFY(!ipc.focusWorkspace(0, QString(), QString()));
    QVERIFY(!ipc.focusWindow(1.5));
    QCOMPARE(failedSpy.count(), 0);

    QVERIFY(!ipc.focusWorkspace(2, QString(), QString()));
    QVERIFY(!ipc.focusWindow(42));
    QVERIFY(!ipc.quit());
    QCOMPARE(failedSpy.count(), 3);
    QCOMPARE(failedSpy.at(0).at(0).toString(), QStringLiteral("focus-workspace"));
    QCOMPARE(failedSpy.at(1).at(0).toString(), QStringLiteral("focus-window"));
    QCOMPARE(failedSpy.at(2).at(0).toString(), QStringLiteral("quit"));
}

QTEST_GUILESS_MAIN(NiriIpcTest)

#include "tst_niriipc.moc"
