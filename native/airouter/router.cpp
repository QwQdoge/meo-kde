#include "router.h"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

Router::Router(bool irreversibleEnabled, QObject *parent)
    : QObject(parent), m_irreversibleEnabled(irreversibleEnabled)
{
}

bool Router::addCapability(Capability capability)
{
    if (capability.id.isEmpty() || capability.title.trimmed().isEmpty()
        || capability.owner.trimmed().isEmpty() || !capability.dispatch
        || m_capabilities.contains(capability.id)
        || (capability.effect == Effect::Irreversible && !capability.describeTarget)) {
        return false;
    }
    m_capabilities.insert(capability.id, std::move(capability));
    return true;
}

QString Router::fingerprint(const QString &id, const QVariantMap &arguments)
{
    const QByteArray canonical = QJsonDocument(QJsonObject{{QStringLiteral("capability"), id},
        {QStringLiteral("arguments"), QJsonObject::fromVariantMap(arguments)}}).toJson(QJsonDocument::Compact);
    return QString::fromLatin1(QCryptographicHash::hash(canonical, QCryptographicHash::Sha256).toHex());
}

QString Router::effectName(Effect effect)
{
    switch (effect) {
    case Effect::Read:
        return QStringLiteral("read");
    case Effect::Session:
        return QStringLiteral("session");
    case Effect::Persistent:
        return QStringLiteral("persistent");
    case Effect::Irreversible:
        return QStringLiteral("irreversible");
    }
    return QStringLiteral("unknown");
}

QString Router::verificationName(Verification verification)
{
    switch (verification) {
    case Verification::OwnerResult:
        return QStringLiteral("owner-result");
    case Verification::ReadBack:
        return QStringLiteral("read-back");
    }
    return QStringLiteral("unknown");
}

QString Router::maturityName(Maturity maturity)
{
    switch (maturity) {
    case Maturity::Preview:
        return QStringLiteral("preview");
    case Maturity::Stable:
        return QStringLiteral("stable");
    }
    return QStringLiteral("unknown");
}

QVariantMap Router::view(const Request &request) const
{
    QVariantMap result{{QStringLiteral("requestId"), request.id},
                       {QStringLiteral("capability"), request.capabilityId},
                       {QStringLiteral("state"), request.state},
                       {QStringLiteral("title"), request.title},
                       {QStringLiteral("target"), request.target},
                       {QStringLiteral("impact"), request.impact},
                       {QStringLiteral("fingerprint"), request.fingerprint},
                       {QStringLiteral("message"), request.message}};
    if (request.expires.isValid())
        result.insert(QStringLiteral("expiresAt"), request.expires.toString(Qt::ISODateWithMs));
    return result;
}

QVariantMap Router::submit(const QString &id, const QVariantMap &arguments, const QString &caller)
{
    const auto it = m_capabilities.constFind(id);
    if (it == m_capabilities.cend())
        return {{QStringLiteral("state"), QStringLiteral("rejected")}, {QStringLiteral("message"), QStringLiteral("Unknown capability")}};
    const Capability &capability = it.value();
    if (capability.effect == Effect::Irreversible && !m_irreversibleEnabled)
        return {{QStringLiteral("state"), QStringLiteral("rejected")}, {QStringLiteral("message"), QStringLiteral("Irreversible capabilities are disabled")}};
    if (arguments.size() != capability.arguments.size())
        return {{QStringLiteral("state"), QStringLiteral("rejected")}, {QStringLiteral("message"), QStringLiteral("Invalid arguments")}};
    for (auto arg = capability.arguments.cbegin(); arg != capability.arguments.cend(); ++arg) {
        const auto supplied = arguments.constFind(arg.key());
        if (supplied == arguments.cend() || supplied->metaType().id() != arg.value())
            return {{QStringLiteral("state"), QStringLiteral("rejected")}, {QStringLiteral("message"), QStringLiteral("Invalid arguments")}};
    }
    Request request;
    request.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    request.capabilityId = id;
    request.caller = caller;
    request.arguments = arguments;
    request.fingerprint = fingerprint(id, arguments);
    request.title = capability.title;
    if (capability.describeTarget)
        request.target = capability.describeTarget(arguments);
    if (capability.effect == Effect::Irreversible && request.target.trimmed().isEmpty())
        return {{QStringLiteral("state"), QStringLiteral("rejected")},
                {QStringLiteral("message"), QStringLiteral("Action target is unavailable")}};
    request.impact = capability.impact;
    request.state = capability.effect == Effect::Irreversible ? QStringLiteral("awaiting_confirmation") : QStringLiteral("running");
    request.created = QDateTime::currentDateTimeUtc();
    if (capability.effect == Effect::Irreversible)
        request.expires = request.created.addSecs(30);
    m_requests.insert(request.id, request);
    emit requestChanged(view(request));
    if (capability.effect == Effect::Irreversible)
        emit confirmationRequired(view(request));
    else
        capability.dispatch(request.id, arguments);
    return view(m_requests.value(request.id));
}

QVariantMap Router::decide(const QString &requestId, const QString &expectedFingerprint, bool approve, const QString &caller)
{
    auto it = m_requests.find(requestId);
    if (it == m_requests.end() || it->caller != caller)
        return {{QStringLiteral("state"), QStringLiteral("rejected")}};
    Request &request = it.value();
    if (request.state != QLatin1String("awaiting_confirmation"))
        return view(request);
    if (request.expires <= QDateTime::currentDateTimeUtc()) {
        request.state = QStringLiteral("expired");
    } else if (!approve) {
        request.state = QStringLiteral("denied");
    } else if (expectedFingerprint != request.fingerprint
               || fingerprint(request.capabilityId, request.arguments) != request.fingerprint
               || !m_capabilities.contains(request.capabilityId) || !m_irreversibleEnabled) {
        request.state = QStringLiteral("rejected");
        request.message = QStringLiteral("Confirmation no longer matches action");
    } else {
        request.state = QStringLiteral("running");
        emit requestChanged(view(request));
        m_capabilities.value(request.capabilityId).dispatch(request.id, request.arguments);
        return view(m_requests.value(requestId));
    }
    emit requestChanged(view(request));
    return view(request);
}

QVariantMap Router::get(const QString &requestId, const QString &caller)
{
    const auto it = m_requests.constFind(requestId);
    if (it == m_requests.cend() || it->caller != caller)
        return {{QStringLiteral("state"), QStringLiteral("rejected")}};
    return view(it.value());
}

QVariantList Router::capabilities() const
{
    QVariantList result;
    for (const auto &capability : m_capabilities) {
        if (capability.effect == Effect::Irreversible && !m_irreversibleEnabled)
            continue;
        result << QVariantMap{
            {QStringLiteral("id"), capability.id},
            {QStringLiteral("title"), capability.title},
            {QStringLiteral("owner"), capability.owner},
            {QStringLiteral("effect"), effectName(capability.effect)},
            {QStringLiteral("verification"), verificationName(capability.verification)},
            {QStringLiteral("maturity"), maturityName(capability.maturity)},
            {QStringLiteral("requiresConfirmation"), capability.effect == Effect::Irreversible},
        };
    }
    return result;
}

void Router::complete(const QString &requestId, bool success, const QString &message)
{
    auto it = m_requests.find(requestId);
    if (it == m_requests.end() || it->state != QLatin1String("running"))
        return;
    it->state = success ? QStringLiteral("completed") : QStringLiteral("failed");
    it->message = message;
    emit requestChanged(view(it.value()));
}

void Router::expirePending(const QDateTime &now)
{
    for (auto it = m_requests.begin(); it != m_requests.end(); ++it) {
        if (it->state == QLatin1String("awaiting_confirmation") && it->expires <= now) {
            it->state = QStringLiteral("expired");
            emit requestChanged(view(it.value()));
        }
    }
    for (auto it = m_requests.begin(); it != m_requests.end();) {
        if (it->state != QLatin1String("running")
            && it->state != QLatin1String("awaiting_confirmation")
            && it->created.addSecs(900) < now)
            it = m_requests.erase(it);
        else
            ++it;
    }
}
