#include "niriipc.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QLocalSocket>
#include <QTimer>

#include <algorithm>
#include <cmath>
#include <functional>
#include <utility>

namespace {

constexpr int InitialReconnectDelay = 1000;
constexpr int MaximumReconnectDelay = 5000;
constexpr int RequestTimeoutMs = 3000;
constexpr double MaximumExactJsonInteger = 9007199254740991.0;

QString socketErrorMessage(QLocalSocket::LocalSocketError error)
{
    const auto message = [](const char *text) {
        return QCoreApplication::translate("NiriIpc", text);
    };
    switch (error) {
    case QLocalSocket::ServerNotFoundError:
        return message("The Niri IPC socket is not available.");
    case QLocalSocket::ConnectionRefusedError:
        return message("Niri refused the IPC connection.");
    case QLocalSocket::SocketTimeoutError:
        return message("Niri did not respond in time.");
    case QLocalSocket::PeerClosedError:
        return message("Niri closed the IPC connection.");
    case QLocalSocket::SocketAccessError:
        return message("The Niri IPC socket cannot be accessed.");
    case QLocalSocket::SocketResourceError:
        return message("There are not enough system resources to connect to Niri.");
    case QLocalSocket::DatagramTooLargeError:
    case QLocalSocket::ConnectionError:
    case QLocalSocket::UnsupportedSocketOperationError:
    case QLocalSocket::OperationError:
    case QLocalSocket::UnknownSocketError:
        return message("Could not communicate with Niri.");
    }
    return message("Could not communicate with Niri.");
}

QString responseError(const QJsonObject &response)
{
    const QJsonValue error = response.value(QStringLiteral("Err"));
    if (error.isString())
        return error.toString();
    if (error.isUndefined())
        return QCoreApplication::translate("NiriIpc", "Niri returned an invalid response.");
    if (error.isObject())
        return QString::fromUtf8(QJsonDocument(error.toObject()).toJson(QJsonDocument::Compact));
    return error.toVariant().toString();
}

QJsonObject actionRequest(const QString &action, const QJsonObject &arguments)
{
    return {{QStringLiteral("Action"), QJsonObject{{action, arguments}}}};
}

} // namespace

class NiriIpc::Private
{
public:
    struct PendingRequest {
        QLocalSocket *socket = nullptr;
        QTimer *timeout = nullptr;
        QByteArray buffer;
        QString action;
        std::function<void(bool)> completion;
        bool finished = false;
    };

    explicit Private(NiriIpc *ipc)
        : q(ipc)
    {
        reconnectTimer.setSingleShot(true);
        handshakeTimer.setSingleShot(true);
        handshakeTimer.setInterval(RequestTimeoutMs);

        QObject::connect(&reconnectTimer, &QTimer::timeout, q, [this] { connectEventStream(); });
        QObject::connect(&handshakeTimer, &QTimer::timeout, q, [this] {
            setError(QCoreApplication::translate("NiriIpc", "Niri did not start the event stream in time."));
            eventSocket.abort();
            scheduleReconnect();
        });
        QObject::connect(&eventSocket, &QLocalSocket::connected, q, [this] {
            eventBuffer.clear();
            awaitingHandshake = true;
            eventSocket.write(QByteArrayLiteral("\"EventStream\"\n"));
            eventSocket.flush();
            handshakeTimer.start();
        });
        QObject::connect(&eventSocket, &QLocalSocket::readyRead, q, [this] {
            eventBuffer.append(eventSocket.readAll());
            processEventBuffer();
        });
        QObject::connect(&eventSocket,
                         &QLocalSocket::errorOccurred,
                         q,
                         [this](QLocalSocket::LocalSocketError error) {
                             if (!initialized)
                                 return;
                             handshakeTimer.stop();
                             setError(socketErrorMessage(error));
                             setConnected(false);
                             scheduleReconnect();
                         });
        QObject::connect(&eventSocket, &QLocalSocket::disconnected, q, [this] {
            if (!initialized)
                return;
            handshakeTimer.stop();
            setConnected(false);
            scheduleReconnect();
        });
    }

    ~Private()
    {
        initialized = false;
        reconnectTimer.stop();
        handshakeTimer.stop();
        QObject::disconnect(&eventSocket, nullptr, q, nullptr);
        eventSocket.abort();

        const auto requests = pendingRequests;
        pendingRequests.clear();
        for (PendingRequest *request : requests) {
            QObject::disconnect(request->socket, nullptr, q, nullptr);
            QObject::disconnect(request->timeout, nullptr, q, nullptr);
            request->socket->abort();
            delete request->socket;
            delete request->timeout;
            delete request;
        }
    }

    NiriIpc *q;
    QLocalSocket eventSocket;
    QTimer reconnectTimer;
    QTimer handshakeTimer;
    QByteArray eventBuffer;
    QList<PendingRequest *> pendingRequests;
    bool initialized = false;
    bool awaitingHandshake = true;
    bool connected = false;
    bool workspaceFocusInFlight = false;
    bool windowFocusInFlight = false;
    bool quitInFlight = false;
    int reconnectDelay = InitialReconnectDelay;
    QString lastError;

    QString socketPath() const
    {
        return qEnvironmentVariable("NIRI_SOCKET").trimmed();
    }

    void initialize()
    {
        if (initialized)
            return;
        initialized = true;
        connectEventStream();
    }

    void connectEventStream()
    {
        if (!initialized || eventSocket.state() != QLocalSocket::UnconnectedState)
            return;

        const QString path = socketPath();
        if (path.isEmpty()) {
            setError(QCoreApplication::translate("NiriIpc", "Niri is not available in this session."));
            scheduleReconnect();
            return;
        }

        eventBuffer.clear();
        awaitingHandshake = true;
        eventSocket.connectToServer(path, QIODevice::ReadWrite);
    }

    void scheduleReconnect()
    {
        if (!initialized || reconnectTimer.isActive())
            return;
        reconnectTimer.start(reconnectDelay);
        reconnectDelay = std::min(MaximumReconnectDelay, reconnectDelay * 2);
    }

    void processEventBuffer()
    {
        qsizetype newline = -1;
        while ((newline = eventBuffer.indexOf('\n')) >= 0) {
            const QByteArray line = eventBuffer.left(newline).trimmed();
            eventBuffer.remove(0, newline + 1);
            if (!line.isEmpty())
                processEventLine(line);
        }
    }

    void processEventLine(const QByteArray &line)
    {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(line, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            const QString detail = parseError.error == QJsonParseError::NoError
                ? QCoreApplication::translate("NiriIpc", "Expected a JSON object.")
                : parseError.errorString();
            setError(QCoreApplication::translate("NiriIpc", "Could not read an event from Niri: %1")
                         .arg(detail));
            emit q->eventParseFailed(QString::fromUtf8(line), detail);
            if (awaitingHandshake) {
                eventSocket.abort();
                scheduleReconnect();
            }
            return;
        }

        const QJsonObject object = document.object();
        if (awaitingHandshake) {
            if (object.contains(QStringLiteral("Err"))) {
                setError(QCoreApplication::translate("NiriIpc", "Niri rejected the event stream: %1")
                             .arg(responseError(object)));
                eventSocket.abort();
                scheduleReconnect();
                return;
            }
            if (object.value(QStringLiteral("Ok")).toString() != QStringLiteral("Handled")) {
                setError(QCoreApplication::translate("NiriIpc", "Niri returned an invalid event-stream response."));
                eventSocket.abort();
                scheduleReconnect();
                return;
            }
            awaitingHandshake = false;
            handshakeTimer.stop();
            reconnectDelay = InitialReconnectDelay;
            setConnected(true);
            setError({});
            return;
        }

        setError({});
        emit q->eventReceived(object.toVariantMap());
    }

    bool sendRequest(const QJsonObject &request,
                     const QString &action,
                     std::function<void(bool)> completion)
    {
        const QString path = socketPath();
        if (path.isEmpty()) {
            const QString message = QCoreApplication::translate("NiriIpc",
                                                                 "Niri is not available in this session.");
            failAction(action, message);
            if (completion)
                completion(false);
            return false;
        }

        auto *pending = new PendingRequest;
        pending->socket = new QLocalSocket(q);
        pending->timeout = new QTimer(q);
        pending->timeout->setSingleShot(true);
        pending->timeout->setInterval(RequestTimeoutMs);
        pending->action = action;
        pending->completion = std::move(completion);
        pendingRequests.append(pending);

        const QByteArray payload = QJsonDocument(request).toJson(QJsonDocument::Compact)
            + QByteArrayLiteral("\n");
        QObject::connect(pending->socket, &QLocalSocket::connected, q, [pending, payload] {
            pending->socket->write(payload);
            pending->socket->flush();
        });
        QObject::connect(pending->socket, &QLocalSocket::readyRead, q, [this, pending] {
            pending->buffer.append(pending->socket->readAll());
            const qsizetype newline = pending->buffer.indexOf('\n');
            if (newline < 0)
                return;

            const QByteArray line = pending->buffer.left(newline).trimmed();
            QJsonParseError parseError;
            const QJsonDocument document = QJsonDocument::fromJson(line, &parseError);
            if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
                finishRequest(pending,
                              false,
                              QCoreApplication::translate("NiriIpc", "Niri returned an invalid response."));
                return;
            }

            const QJsonObject response = document.object();
            if (response.contains(QStringLiteral("Ok"))) {
                finishRequest(pending, true, {});
                return;
            }
            finishRequest(pending, false, responseError(response));
        });
        QObject::connect(pending->socket,
                         &QLocalSocket::errorOccurred,
                         q,
                         [this, pending](QLocalSocket::LocalSocketError error) {
                             finishRequest(pending, false, socketErrorMessage(error));
                         });
        QObject::connect(pending->timeout, &QTimer::timeout, q, [this, pending] {
            finishRequest(pending,
                          false,
                          QCoreApplication::translate("NiriIpc", "Niri did not respond in time."));
        });

        pending->timeout->start();
        pending->socket->connectToServer(path, QIODevice::ReadWrite);
        return true;
    }

    void finishRequest(PendingRequest *request, bool success, const QString &detail)
    {
        if (request->finished)
            return;
        request->finished = true;
        pendingRequests.removeOne(request);

        QObject::disconnect(request->socket, nullptr, q, nullptr);
        QObject::disconnect(request->timeout, nullptr, q, nullptr);
        request->timeout->stop();
        request->socket->abort();
        request->socket->deleteLater();
        request->timeout->deleteLater();

        const QString action = request->action;
        std::function<void(bool)> completion = std::move(request->completion);
        delete request;

        if (success) {
            setError({});
            emit q->actionCompleted(action);
        } else {
            const QString message = detail.isEmpty()
                ? QCoreApplication::translate("NiriIpc", "Niri could not complete the requested action.")
                : detail;
            failAction(action, message);
        }
        if (completion)
            completion(success);
    }

    void failAction(const QString &action, const QString &message)
    {
        setError(message);
        emit q->actionFailed(action, message);
    }

    bool focusWorkspace(int workspaceIndex,
                        const QString &outputName,
                        const QString &focusedOutputName)
    {
        if (workspaceIndex < 1 || workspaceFocusInFlight)
            return false;

        workspaceFocusInFlight = true;
        const auto focusTargetWorkspace = [this, workspaceIndex] {
            const QJsonObject request = actionRequest(
                QStringLiteral("FocusWorkspace"),
                {{QStringLiteral("reference"),
                  QJsonObject{{QStringLiteral("Index"), workspaceIndex}}}});
            return sendRequest(request, QStringLiteral("focus-workspace"), [this](bool) {
                workspaceFocusInFlight = false;
            });
        };

        const QString targetOutput = outputName.trimmed();
        const QString currentOutput = focusedOutputName.trimmed();
        const bool needsMonitorFocus = !targetOutput.isEmpty()
            && targetOutput.compare(currentOutput, Qt::CaseInsensitive) != 0;
        if (!needsMonitorFocus) {
            return focusTargetWorkspace();
        }

        const QJsonObject request = actionRequest(
            QStringLiteral("FocusMonitor"),
            {{QStringLiteral("output"), targetOutput}});
        return sendRequest(request,
                           QStringLiteral("focus-monitor"),
                           [this, focusTargetWorkspace](bool success) {
                               if (success) {
                                   focusTargetWorkspace();
                                   return;
                               }
                               workspaceFocusInFlight = false;
                           });
    }

    bool focusWindow(double windowId)
    {
        if (!std::isfinite(windowId) || std::trunc(windowId) != windowId || windowId < 1.0
            || windowId > MaximumExactJsonInteger || windowFocusInFlight) {
            return false;
        }

        windowFocusInFlight = true;
        const QJsonObject request = actionRequest(
            QStringLiteral("FocusWindow"),
            {{QStringLiteral("id"), static_cast<qint64>(windowId)}});
        return sendRequest(request, QStringLiteral("focus-window"), [this](bool) {
            windowFocusInFlight = false;
        });
    }

    bool quit(bool skipConfirmation)
    {
        if (quitInFlight)
            return false;

        quitInFlight = true;
        const QJsonObject request = actionRequest(
            QStringLiteral("Quit"),
            {{QStringLiteral("skip_confirmation"), skipConfirmation}});
        return sendRequest(request, QStringLiteral("quit"), [this](bool) {
            quitInFlight = false;
        });
    }

    void setConnected(bool value)
    {
        if (connected == value)
            return;
        connected = value;
        emit q->connectedChanged();
    }

    void setError(const QString &value)
    {
        if (lastError == value)
            return;
        lastError = value;
        emit q->lastErrorChanged();
    }
};

NiriIpc::NiriIpc(QObject *parent)
    : QObject(parent)
    , d(std::make_unique<Private>(this))
{
}

NiriIpc::~NiriIpc() = default;

bool NiriIpc::available() const
{
    return d->connected;
}

bool NiriIpc::connected() const
{
    return d->connected;
}

QString NiriIpc::lastError() const
{
    return d->lastError;
}

void NiriIpc::initialize()
{
    d->initialize();
}

bool NiriIpc::focusWorkspace(int workspaceIndex,
                             const QString &outputName,
                             const QString &focusedOutputName)
{
    return d->focusWorkspace(workspaceIndex, outputName, focusedOutputName);
}

bool NiriIpc::focusWindow(double windowId)
{
    return d->focusWindow(windowId);
}

bool NiriIpc::quit(bool skipConfirmation)
{
    return d->quit(skipConfirmation);
}
