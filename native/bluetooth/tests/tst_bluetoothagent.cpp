#include "bluetoothagent.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QSignalSpy>
#include <QTest>
#include <QUuid>

class BluetoothAgentTest : public QObject
{
    Q_OBJECT

private slots:
    void startsIdle();
    void formatsDisplayRequests();
    void completesDelayedDbusReplies();
};

void BluetoothAgentTest::startsIdle()
{
    BluetoothAgent agent;
    QVERIFY(!agent.ready());
    QVERIFY(!agent.hasRequest());
    QVERIFY(agent.request().isEmpty());
    QVERIFY(!agent.respond(true, QString()));
}

void BluetoothAgentTest::formatsDisplayRequests()
{
    BluetoothAgent agent;
    agent.DisplayPasskey(QDBusObjectPath(QStringLiteral("/org/bluez/test/device")), 42, 2);
    QVERIFY(agent.hasRequest());
    QCOMPARE(agent.request().value(QStringLiteral("event")).toString(), QStringLiteral("display"));
    QCOMPARE(agent.request().value(QStringLiteral("type")).toString(), QStringLiteral("passkey"));
    QCOMPARE(agent.request().value(QStringLiteral("value")).toString(), QStringLiteral("000042"));
    QCOMPARE(agent.request().value(QStringLiteral("entered")).toUInt(), 2U);
    agent.dismissDisplay();
    QVERIFY(!agent.hasRequest());
}

void BluetoothAgentTest::completesDelayedDbusReplies()
{
    QDBusConnection server = QDBusConnection::sessionBus();
    if (!server.isConnected())
        QSKIP("No D-Bus session bus is available");

    BluetoothAgent agent;
    const QString objectPath = QStringLiteral("/org/ateria/BluetoothAgentTest");
    QVERIFY(server.registerObject(objectPath, &agent, QDBusConnection::ExportAllSlots));

    const QString connectionName = QStringLiteral("ateria-bluetooth-test-%1")
                                       .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    QDBusConnection client = QDBusConnection::connectToBus(QDBusConnection::SessionBus,
                                                           connectionName);
    QVERIFY(client.isConnected());
    QDBusMessage confirmationMessage = QDBusMessage::createMethodCall(
        server.baseService(),
        objectPath,
        QStringLiteral("org.bluez.Agent1"),
        QStringLiteral("RequestConfirmation"));
    confirmationMessage.setArguments(
        {QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/bluez/test/device"))), 42U});
    QDBusPendingCall confirmationCall = client.asyncCall(confirmationMessage, 2000);
    QDBusPendingCallWatcher confirmationWatcher(confirmationCall);
    QTRY_VERIFY_WITH_TIMEOUT(agent.hasRequest(), 2000);
    QCOMPARE(agent.request().value(QStringLiteral("type")).toString(), QStringLiteral("confirmation"));
    QCOMPARE(agent.request().value(QStringLiteral("value")).toString(), QStringLiteral("000042"));

    QDBusMessage duplicateMessage = QDBusMessage::createMethodCall(
        server.baseService(),
        objectPath,
        QStringLiteral("org.bluez.Agent1"),
        QStringLiteral("RequestAuthorization"));
    duplicateMessage.setArguments(
        {QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/bluez/test/other_device")))});
    QDBusPendingCallWatcher duplicateWatcher(client.asyncCall(duplicateMessage, 2000));
    QTRY_VERIFY_WITH_TIMEOUT(duplicateWatcher.isFinished(), 2000);
    const QDBusPendingReply<> duplicateReply = duplicateWatcher;
    QVERIFY(duplicateReply.isError());
    QCOMPARE(duplicateReply.error().name(), QStringLiteral("org.bluez.Error.Canceled"));

    QVERIFY(agent.respond(true, QString()));
    QTRY_VERIFY_WITH_TIMEOUT(confirmationWatcher.isFinished(), 2000);
    const QDBusPendingReply<> confirmationReply = confirmationWatcher;
    QVERIFY2(!confirmationReply.isError(), qPrintable(confirmationReply.error().message()));

    QDBusMessage passkeyMessage = QDBusMessage::createMethodCall(server.baseService(),
                                                                 objectPath,
                                                                 QStringLiteral("org.bluez.Agent1"),
                                                                 QStringLiteral("RequestPasskey"));
    passkeyMessage.setArguments(
        {QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/bluez/test/device")))});
    QDBusPendingCall passkeyCall = client.asyncCall(passkeyMessage, 2000);
    QDBusPendingCallWatcher passkeyWatcher(passkeyCall);
    QTRY_VERIFY_WITH_TIMEOUT(agent.hasRequest(), 2000);
    QCOMPARE(agent.request().value(QStringLiteral("type")).toString(), QStringLiteral("passkey"));
    QVERIFY(agent.respond(true, QStringLiteral("123456")));
    QTRY_VERIFY_WITH_TIMEOUT(passkeyWatcher.isFinished(), 2000);
    const QDBusPendingReply<quint32> passkeyReply = passkeyWatcher;
    QVERIFY2(!passkeyReply.isError(), qPrintable(passkeyReply.error().message()));
    QCOMPARE(passkeyReply.value(), 123456U);

    QDBusPendingCallWatcher invalidPasskeyWatcher(client.asyncCall(passkeyMessage, 2000));
    QTRY_VERIFY_WITH_TIMEOUT(agent.hasRequest(), 2000);
    QVERIFY(agent.respond(true, QStringLiteral("1234567")));
    QTRY_VERIFY_WITH_TIMEOUT(invalidPasskeyWatcher.isFinished(), 2000);
    const QDBusPendingReply<quint32> invalidPasskeyReply = invalidPasskeyWatcher;
    QVERIFY(invalidPasskeyReply.isError());
    QCOMPARE(invalidPasskeyReply.error().name(), QStringLiteral("org.bluez.Error.Rejected"));

    QDBusMessage pinMessage = QDBusMessage::createMethodCall(server.baseService(),
                                                             objectPath,
                                                             QStringLiteral("org.bluez.Agent1"),
                                                             QStringLiteral("RequestPinCode"));
    pinMessage.setArguments(
        {QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/bluez/test/device")))});
    QDBusPendingCallWatcher pinWatcher(client.asyncCall(pinMessage, 2000));
    QTRY_VERIFY_WITH_TIMEOUT(agent.hasRequest(), 2000);
    QVERIFY(agent.respond(true, QStringLiteral("1234")));
    QTRY_VERIFY_WITH_TIMEOUT(pinWatcher.isFinished(), 2000);
    const QDBusPendingReply<QString> pinReply = pinWatcher;
    QVERIFY2(!pinReply.isError(), qPrintable(pinReply.error().message()));
    QCOMPARE(pinReply.value(), QStringLiteral("1234"));

    QDBusMessage authorizationMessage = QDBusMessage::createMethodCall(
        server.baseService(),
        objectPath,
        QStringLiteral("org.bluez.Agent1"),
        QStringLiteral("RequestAuthorization"));
    authorizationMessage.setArguments(
        {QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/bluez/test/device")))});
    QDBusPendingCallWatcher authorizationWatcher(client.asyncCall(authorizationMessage, 2000));
    QTRY_VERIFY_WITH_TIMEOUT(agent.hasRequest(), 2000);
    QVERIFY(agent.respond(false, QString()));
    QTRY_VERIFY_WITH_TIMEOUT(authorizationWatcher.isFinished(), 2000);
    const QDBusPendingReply<> authorizationReply = authorizationWatcher;
    QVERIFY(authorizationReply.isError());
    QCOMPARE(authorizationReply.error().name(), QStringLiteral("org.bluez.Error.Rejected"));

    server.unregisterObject(objectPath);
    QDBusConnection::disconnectFromBus(connectionName);
}

QTEST_GUILESS_MAIN(BluetoothAgentTest)

#include "tst_bluetoothagent.moc"
