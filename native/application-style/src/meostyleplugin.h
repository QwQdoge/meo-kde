#pragma once

#include <QtWidgets/QStylePlugin>

class MeoStylePlugin final : public QStylePlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QStyleFactoryInterface_iid FILE "../meostyle.json")

public:
    QStyle *create(const QString &key) override;
};
