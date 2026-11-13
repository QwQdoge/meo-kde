#pragma once

#include <QJsonObject>
#include <QString>
#include <QVariantMap>

// Live-installer helpers for the Router. Everything here is propose-only or
// read-only: the Installer (root) remains the authority and treats the
// proposal file as untrusted input that the person must review and apply.
namespace InstallerCapabilities {

// True only in the MeoArch Live environment (or when a test overrides it).
bool liveEnvironment();

// Validates an AI proposal. Only allow-listed, shape-checked fields pass.
// Accounts, usernames, passwords and erase mode are never proposable.
// Returns an empty object and sets *error on failure.
QJsonObject normalizeProposal(const QJsonObject &input, QString *error);

// Writes the validated proposal to the Live user's runtime directory.
// Returns true on success; *message carries a human-readable result.
bool submitProposal(const QString &proposalJson, QString *message);

// Last N lines (1..200, each at most 400 characters) of the installer log,
// as a JSON array string.
bool readLog(int lines, QString *message);

// Detected storage devices as a JSON array string. Read-only; a device being
// listed does not mean it is eligible. The Installer decides eligibility.
bool listDisks(QString *message);

QString proposalPath();

} // namespace InstallerCapabilities
