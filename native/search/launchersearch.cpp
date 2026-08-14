#include "launchersearch.h"

#include "launchersearchmodel.h"

LauncherSearch::LauncherSearch(QObject *parent)
    : QObject(parent)
{
}

QString LauncherSearch::applicationKey(const QVariant &application) const
{
    return LauncherSearchModel::applicationKey(application);
}
