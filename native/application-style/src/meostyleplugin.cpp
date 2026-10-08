#include "meostyleplugin.h"

#include "meostylecontent.h"

QStyle *MeoStylePlugin::create(const QString &key)
{
    return key.compare(QLatin1String("Meo"), Qt::CaseInsensitive) == 0 ? new MeoStyleContent : nullptr;
}
