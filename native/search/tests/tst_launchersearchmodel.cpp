#include "launchersearchmodel.h"

#include <QtTest>

namespace {

QVariantMap application(const QString &name,
                        const QString &id = {},
                        const QVariantMap &extra = {})
{
    QVariantMap entry{{QStringLiteral("name"), name},
                      {QStringLiteral("id"),
                       id.isEmpty() ? name.toLower().replace(u' ', u'-') + QStringLiteral(".desktop")
                                    : id},
                      {QStringLiteral("genericName"), QString()},
                      {QStringLiteral("comment"), QString()},
                      {QStringLiteral("keywords"), QStringList()},
                      {QStringLiteral("categories"), QStringList()},
                      {QStringLiteral("startupClass"), QString()},
                      {QStringLiteral("command"), QStringList()},
                      {QStringLiteral("execString"), QString()}};
    for (auto iterator = extra.cbegin(); iterator != extra.cend(); ++iterator)
        entry.insert(iterator.key(), iterator.value());
    return entry;
}

QStringList resultNames(const LauncherSearchModel &model)
{
    QStringList names;
    const QVariantList results = model.results();
    names.reserve(results.size());
    for (const QVariant &entry : results)
        names.append(entry.toMap().value(QStringLiteral("name")).toString());
    return names;
}

} // namespace

class LauncherSearchModelTest : public QObject
{
    Q_OBJECT

private slots:
    void ranksPrefixAndWordMatches();
    void handlesFuzzyEditsAndTranspositions();
    void matchesAcronymsAccentsAndMetadata();
    void requiresEveryQueryTerm();
    void appliesUsageWithoutOverridingExactNames();
    void ranksEmptyQueriesByCountThenRecency();
    void benchmarkRanking();
};

void LauncherSearchModelTest::ranksPrefixAndWordMatches()
{
    QCOMPARE(LauncherSearchModel::applicationKey(
                 application(QStringLiteral("Code"), QStringLiteral("code.desktop"))),
             QStringLiteral("desktop:code.desktop"));

    LauncherSearchModel model;
    model.setApplications({application(QStringLiteral("Visual Studio Code")),
                           application(QStringLiteral("Code")),
                           application(QStringLiteral("VSCodium"))});
    model.setQuery(QStringLiteral("code"));
    QCOMPARE(resultNames(model),
             QStringList({QStringLiteral("Code"), QStringLiteral("Visual Studio Code")}));
}

void LauncherSearchModelTest::handlesFuzzyEditsAndTranspositions()
{
    QCOMPARE(LauncherSearchModel::boundedEditDistance(QStringLiteral("calculator"),
                                                      QStringLiteral("calclator"), 2),
             1);
    QCOMPARE(LauncherSearchModel::boundedEditDistance(QStringLiteral("calculator"),
                                                      QStringLiteral("caluclator"), 2),
             1);
    QCOMPARE(LauncherSearchModel::boundedEditDistance(QStringLiteral("calculator"),
                                                      QStringLiteral("calculattor"), 2),
             1);
    QCOMPARE(LauncherSearchModel::boundedEditDistance(QStringLiteral("calculator"),
                                                      QStringLiteral("calculatpr"), 2),
             1);
    QCOMPARE(LauncherSearchModel::boundedEditDistance(QStringLiteral("calculator"),
                                                      QStringLiteral("calendar"), 2),
             3);

    LauncherSearchModel model;
    model.setApplications({application(QStringLiteral("Calculator")),
                           application(QStringLiteral("Calendar"))});
    model.setQuery(QStringLiteral("calclator"));
    QCOMPARE(resultNames(model), QStringList({QStringLiteral("Calculator")}));
    model.setQuery(QStringLiteral("caluclator"));
    QCOMPARE(resultNames(model), QStringList({QStringLiteral("Calculator")}));
}

void LauncherSearchModelTest::matchesAcronymsAccentsAndMetadata()
{
    LauncherSearchModel model;
    model.setApplications({
        application(QStringLiteral("Visual Studio Code")),
        application(QStringLiteral("Virtual Machine Manager")),
        application(QStringLiteral("Résumé Builder")),
        application(QStringLiteral("Firefox"),
                    QStringLiteral("firefox.desktop"),
                    {{QStringLiteral("keywords"),
                      QStringList({QStringLiteral("browser"), QStringLiteral("internet"),
                                   QStringLiteral("web")})}}),
        application(QStringLiteral("GNOME Terminal"),
                    QStringLiteral("org.gnome.Terminal.desktop"))});

    model.setQuery(QStringLiteral("vsc"));
    QCOMPARE(resultNames(model), QStringList({QStringLiteral("Visual Studio Code")}));
    model.setQuery(QStringLiteral("resume"));
    QCOMPARE(resultNames(model), QStringList({QStringLiteral("Résumé Builder")}));
    model.setQuery(QStringLiteral("browser"));
    QCOMPARE(resultNames(model), QStringList({QStringLiteral("Firefox")}));
    model.setQuery(QStringLiteral("org terminal"));
    QCOMPARE(resultNames(model), QStringList({QStringLiteral("GNOME Terminal")}));
}

void LauncherSearchModelTest::requiresEveryQueryTerm()
{
    LauncherSearchModel model;
    model.setApplications({application(QStringLiteral("Firefox")),
                           application(QStringLiteral("Files"))});
    model.setQuery(QStringLiteral("fire music"));
    QVERIFY(model.results().isEmpty());
    model.setQuery(QStringLiteral("zzzz"));
    QVERIFY(model.results().isEmpty());
}

void LauncherSearchModelTest::appliesUsageWithoutOverridingExactNames()
{
    constexpr qint64 now = 1'785'772'800'000;
    LauncherSearchModel model;
    model.setRankingTime(now);
    model.setApplications({application(QStringLiteral("Visual Studio Code"),
                                       QStringLiteral("code.desktop")),
                           application(QStringLiteral("Visual Studio Codium"),
                                       QStringLiteral("codium.desktop"))});
    model.setUsageHistory({
        {QStringLiteral("desktop:codium.desktop"),
         QVariantMap{{QStringLiteral("count"), 20},
                     {QStringLiteral("lastLaunched"), now - 60'000}}}});
    model.setQuery(QStringLiteral("visual stud"));
    QCOMPARE(resultNames(model),
             QStringList({QStringLiteral("Visual Studio Codium"),
                          QStringLiteral("Visual Studio Code")}));

    model.setApplications({application(QStringLiteral("Visual Studio Code"),
                                       QStringLiteral("visual-studio-code.desktop")),
                           application(QStringLiteral("Code"),
                                       QStringLiteral("code.desktop"))});
    model.setUsageHistory({
        {QStringLiteral("desktop:visual-studio-code.desktop"),
         QVariantMap{{QStringLiteral("count"), 1000},
                     {QStringLiteral("lastLaunched"), now}}}});
    model.setQuery(QStringLiteral("code"));
    QCOMPARE(resultNames(model),
             QStringList({QStringLiteral("Code"), QStringLiteral("Visual Studio Code")}));
}

void LauncherSearchModelTest::ranksEmptyQueriesByCountThenRecency()
{
    constexpr qint64 now = 1'785'772'800'000;
    LauncherSearchModel model;
    model.setRankingTime(now);
    model.setApplications({application(QStringLiteral("Calculator"),
                                       QStringLiteral("calculator.desktop")),
                           application(QStringLiteral("Calendar"),
                                       QStringLiteral("calendar.desktop")),
                           application(QStringLiteral("Firefox"),
                                       QStringLiteral("firefox.desktop"))});
    model.setUsageHistory({
        {QStringLiteral("desktop:calendar.desktop"),
         QVariantMap{{QStringLiteral("count"), 8},
                     {QStringLiteral("lastLaunched"), now - 30 * 86'400'000LL}}},
        {QStringLiteral("desktop:firefox.desktop"),
         QVariantMap{{QStringLiteral("count"), 8},
                     {QStringLiteral("lastLaunched"), now - 60'000}}}});
    QCOMPARE(resultNames(model),
             QStringList({QStringLiteral("Firefox"), QStringLiteral("Calendar"),
                          QStringLiteral("Calculator")}));

    model.setApplications({application(QStringLiteral("Old Favorite"),
                                       QStringLiteral("old.desktop")),
                           application(QStringLiteral("Recent Choice"),
                                       QStringLiteral("recent.desktop"))});
    model.setUsageHistory({
        {QStringLiteral("desktop:old.desktop"),
         QVariantMap{{QStringLiteral("count"), 1000},
                     {QStringLiteral("lastLaunched"), now - 365 * 86'400'000LL}}},
        {QStringLiteral("desktop:recent.desktop"),
         QVariantMap{{QStringLiteral("count"), 1},
                     {QStringLiteral("lastLaunched"), now}}}});
    QCOMPARE(resultNames(model),
             QStringList({QStringLiteral("Old Favorite"), QStringLiteral("Recent Choice")}));
}

void LauncherSearchModelTest::benchmarkRanking()
{
    LauncherSearchModel model;
    QVariantList applications;
    applications.reserve(300);
    for (int index = 0; index < 300; ++index) {
        applications.append(application(
            QStringLiteral("Application Suite %1").arg(index),
            QStringLiteral("org.example.application%1.desktop").arg(index),
            {{QStringLiteral("genericName"), QStringLiteral("Productivity Utility")},
             {QStringLiteral("comment"), QStringLiteral("Manage documents, media, and projects")},
             {QStringLiteral("keywords"),
              QStringList({QStringLiteral("document"), QStringLiteral("project"),
                           QStringLiteral("utility"), QStringLiteral("application")})},
             {QStringLiteral("categories"),
              QStringList({QStringLiteral("Utility"), QStringLiteral("Office")})},
             {QStringLiteral("startupClass"), QStringLiteral("Application%1").arg(index)},
             {QStringLiteral("command"), QStringList({QStringLiteral("application-%1").arg(index)})},
             {QStringLiteral("execString"), QStringLiteral("application-%1 %U").arg(index)}}));
    }
    model.setApplications(applications);

    bool alternate = false;
    QBENCHMARK {
        alternate = !alternate;
        model.setQuery(alternate ? QStringLiteral("aplication 27")
                                 : QStringLiteral("aplication 28"));
    }
}

QTEST_GUILESS_MAIN(LauncherSearchModelTest)

#include "tst_launchersearchmodel.moc"
