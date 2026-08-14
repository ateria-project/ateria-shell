#include "launchersearchmodel.h"

#include <QDateTime>
#include <QJSValue>
#include <QMetaType>
#include <QRegularExpression>
#include <QStringList>

#include <algorithm>
#include <cmath>
#include <limits>
#include <optional>
#include <utility>

namespace {

constexpr double DayInMilliseconds = 24.0 * 60.0 * 60.0 * 1000.0;
constexpr double MaximumUsageBoost = 28.0;
constexpr int NoMatch = std::numeric_limits<int>::max() / 4;

struct PreparedText {
    QString normalized;
    QStringList words;
    QString compact;
    QString acronym;
};

struct Field {
    PreparedText text;
    int penalty = 0;
};

struct UsageData {
    double boost = 0.0;
    double count = 0.0;
    qint64 lastLaunched = 0;
};

struct IndexedApplication {
    QVariant entry;
    QString key;
    PreparedText name;
    QVector<Field> fields;
    QString sortName;
    QString sortId;
    UsageData usage;
};

struct PreparedQuery {
    QString normalized;
    QStringList terms;
};

struct Match {
    int priority = 2;
    double relevance = 0.0;
};

struct RankedApplication {
    const IndexedApplication *application = nullptr;
    int priority = 2;
    double score = 0.0;
    double usage = 0.0;
    double usageCount = 0.0;
    qint64 lastLaunched = 0;
};

QString normalizeText(const QString &value)
{
    static const QRegularExpression combiningMarks(
        QStringLiteral("[\\x{0300}-\\x{036f}]"));
    static const QRegularExpression desktopSeparators(
        QStringLiteral("[._/\\\\-]+"));
    static const QRegularExpression whitespace(QStringLiteral("\\s+"));

    QString normalized = value.toLower().normalized(QString::NormalizationForm_KD);
    normalized.remove(combiningMarks);
    normalized.replace(desktopSeparators, QStringLiteral(" "));
    normalized.replace(whitespace, QStringLiteral(" "));
    return normalized.trimmed();
}

PreparedText prepareText(const QString &value)
{
    PreparedText prepared;
    prepared.normalized = normalizeText(value);
    if (!prepared.normalized.isEmpty())
        prepared.words = prepared.normalized.split(u' ', Qt::SkipEmptyParts);
    prepared.compact = prepared.normalized;
    prepared.compact.remove(u' ');
    for (const QString &word : std::as_const(prepared.words)) {
        if (!word.isEmpty())
            prepared.acronym.append(word.front());
    }
    return prepared;
}

PreparedQuery prepareQuery(const QString &value)
{
    PreparedQuery query;
    query.normalized = normalizeText(value);
    if (!query.normalized.isEmpty())
        query.terms = query.normalized.split(u' ', Qt::SkipEmptyParts);
    return query;
}

QVariant entryValue(const QVariant &entry, const QString &name)
{
    if (entry.metaType().id() == QMetaType::QVariantMap)
        return entry.toMap().value(name);
    if (entry.metaType().id() == QMetaType::QVariantHash)
        return entry.toHash().value(name);
    if (entry.metaType().id() == qMetaTypeId<QJSValue>())
        return entry.value<QJSValue>().property(name).toVariant();
    if (entry.canConvert<QObject *>()) {
        if (QObject *object = entry.value<QObject *>())
            return object->property(name.toUtf8().constData());
    }
    return {};
}

QString listText(const QVariant &value)
{
    if (!value.isValid() || value.isNull())
        return {};
    if (value.metaType().id() == QMetaType::QStringList)
        return value.toStringList().join(u' ');
    if (value.metaType().id() == QMetaType::QVariantList) {
        QStringList parts;
        const QVariantList values = value.toList();
        parts.reserve(values.size());
        for (const QVariant &part : values)
            parts.append(part.toString());
        return parts.join(u' ');
    }
    if (value.metaType().id() == qMetaTypeId<QJSValue>())
        return listText(value.value<QJSValue>().toVariant());
    return value.toString();
}

int maximumEditDistance(qsizetype length)
{
    if (length < 3)
        return 0;
    return std::min(3, static_cast<int>((length + 2) / 4));
}

int boundedEditDistance(const QString &left, const QString &right, int limit)
{
    if (left == right)
        return 0;
    if (std::abs(left.size() - right.size()) > limit)
        return limit + 1;

    thread_local QVector<int> rowStorage;
    const qsizetype rowSize = right.size() + 1;
    rowStorage.resize(rowSize * 3);
    int *twoRowsAgo = rowStorage.data();
    int *previous = twoRowsAgo + rowSize;
    int *current = previous + rowSize;
    for (qsizetype column = 0; column <= right.size(); ++column)
        previous[column] = static_cast<int>(column);

    for (qsizetype row = 1; row <= left.size(); ++row) {
        current[0] = static_cast<int>(row);
        int rowMinimum = static_cast<int>(row);

        for (qsizetype column = 1; column <= right.size(); ++column) {
            const int substitutionCost = left.at(row - 1) == right.at(column - 1) ? 0 : 1;
            int distance = std::min({previous[column] + 1,
                                     current[column - 1] + 1,
                                     previous[column - 1] + substitutionCost});

            if (row > 1 && column > 1
                && left.at(row - 1) == right.at(column - 2)
                && left.at(row - 2) == right.at(column - 1)) {
                distance = std::min(distance, twoRowsAgo[column - 2] + 1);
            }

            current[column] = distance;
            rowMinimum = std::min(rowMinimum, distance);
        }

        if (rowMinimum > limit)
            return limit + 1;

        int *reusable = twoRowsAgo;
        twoRowsAgo = previous;
        previous = current;
        current = reusable;
    }

    return previous[right.size()];
}

int subsequenceScore(const QString &needle, const QString &haystack)
{
    if (needle.size() < 2)
        return NoMatch;

    qsizetype nextHaystackIndex = 0;
    qsizetype firstMatch = -1;
    qsizetype previousMatch = -1;
    int gapCost = 0;
    int boundaryMatches = 0;

    for (const QChar character : needle) {
        const qsizetype matchIndex = haystack.indexOf(character, nextHaystackIndex);
        if (matchIndex < 0)
            return NoMatch;
        if (firstMatch < 0)
            firstMatch = matchIndex;
        if (previousMatch >= 0 && matchIndex != previousMatch + 1)
            gapCost += 6 + std::max<qsizetype>(0, matchIndex - previousMatch - 2) * 2;
        if (matchIndex == 0 || haystack.at(matchIndex - 1) == u' ')
            ++boundaryMatches;
        previousMatch = matchIndex;
        nextHaystackIndex = matchIndex + 1;
    }

    const qsizetype span = previousMatch - firstMatch + 1;
    if (needle.size() < 5 && span > needle.size() * 3)
        return NoMatch;

    return 210 + static_cast<int>(firstMatch * 2) + gapCost
        + static_cast<int>(std::max<qsizetype>(0, span - needle.size()) * 2)
        - boundaryMatches * 5;
}

int preparedTermScore(const QString &term, const PreparedText &prepared)
{
    const QString &text = prepared.normalized;
    if (term.isEmpty() || text.isEmpty())
        return NoMatch;
    if (term == text)
        return 0;

    int bestScore = NoMatch;
    for (qsizetype index = 0; index < prepared.words.size(); ++index) {
        const QString &word = prepared.words.at(index);
        if (word == term) {
            bestScore = std::min(bestScore, 12 + static_cast<int>(index));
        } else if (word.startsWith(term)) {
            bestScore = std::min(bestScore,
                                 42 + static_cast<int>(index * 2)
                                     + std::min(12, static_cast<int>(word.size() - term.size())));
        }
    }

    if (text.startsWith(term))
        bestScore = std::min(bestScore, 28 + std::min(12, static_cast<int>(text.size() - term.size())));
    if (prepared.compact == term) {
        bestScore = std::min(bestScore, 18);
    } else if (prepared.compact.startsWith(term)) {
        bestScore = std::min(bestScore,
                             52 + std::min(12, static_cast<int>(prepared.compact.size() - term.size())));
    }
    if (prepared.acronym == term) {
        bestScore = std::min(bestScore, 24);
    } else if (term.size() >= 2 && prepared.acronym.startsWith(term)) {
        bestScore = std::min(bestScore,
                             48 + static_cast<int>(prepared.acronym.size() - term.size()));
    }

    const qsizetype substringIndex = text.indexOf(term);
    if (substringIndex >= 0)
        bestScore = std::min(bestScore, 82 + static_cast<int>(substringIndex));
    const qsizetype compactSubstringIndex = prepared.compact.indexOf(term);
    if (compactSubstringIndex >= 0)
        bestScore = std::min(bestScore, 96 + static_cast<int>(compactSubstringIndex));
    if (bestScore < 132)
        return bestScore;

    const int allowedDistance = maximumEditDistance(term.size());
    if (allowedDistance > 0) {
        for (qsizetype index = 0; index < prepared.words.size(); ++index) {
            const QString &word = prepared.words.at(index);
            if (std::abs(word.size() - term.size()) > allowedDistance)
                continue;
            const int distance = boundedEditDistance(term, word, allowedDistance);
            if (distance <= allowedDistance) {
                bestScore = std::min(bestScore,
                                     132 + distance * 18 + static_cast<int>(index * 2)
                                         + static_cast<int>(std::abs(word.size() - term.size())));
            }
        }
    }

    return std::min(bestScore, subsequenceScore(term, text));
}

QString applicationKeyForEntry(const QVariant &entry)
{
    const QString id = entryValue(entry, QStringLiteral("id")).toString().trimmed();
    if (!id.isEmpty())
        return QStringLiteral("desktop:") + id;
    return QStringLiteral("name:") + normalizeText(entryValue(entry, QStringLiteral("name")).toString());
}

QVector<Field> applicationFields(const QVariant &entry, const PreparedText &preparedName)
{
    QVector<Field> fields;
    QHash<QString, qsizetype> fieldIndexes;

    const auto appendField = [&](const PreparedText &prepared, int penalty) {
        if (prepared.normalized.isEmpty())
            return;
        const auto existing = fieldIndexes.constFind(prepared.normalized);
        if (existing != fieldIndexes.cend()) {
            fields[*existing].penalty = std::min(fields[*existing].penalty, penalty);
            return;
        }
        fieldIndexes.insert(prepared.normalized, fields.size());
        fields.append({prepared, penalty});
    };

    appendField(preparedName, 0);
    appendField(prepareText(entryValue(entry, QStringLiteral("genericName")).toString()), 72);
    appendField(prepareText(listText(entryValue(entry, QStringLiteral("keywords")))), 76);
    QString id = entryValue(entry, QStringLiteral("id")).toString();
    if (id.endsWith(QStringLiteral(".desktop"), Qt::CaseInsensitive))
        id.chop(8);
    appendField(prepareText(id), 88);
    appendField(prepareText(entryValue(entry, QStringLiteral("startupClass")).toString()), 92);
    appendField(prepareText(entryValue(entry, QStringLiteral("comment")).toString()), 112);
    appendField(prepareText(listText(entryValue(entry, QStringLiteral("categories")))), 124);
    appendField(prepareText(listText(entryValue(entry, QStringLiteral("command")))), 128);
    appendField(prepareText(entryValue(entry, QStringLiteral("execString")).toString()), 132);
    return fields;
}

UsageData usageData(const QString &key, const QVariantMap &history, qint64 now)
{
    const QVariantMap record = history.value(key).toMap();
    if (record.isEmpty())
        return {};

    bool countValid = false;
    const double count = record.value(QStringLiteral("count")).toDouble(&countValid);
    if (!countValid || !std::isfinite(count) || count <= 0.0)
        return {};

    bool launchedValid = false;
    const double launchedValue = record.value(QStringLiteral("lastLaunched")).toDouble(&launchedValid);
    const qint64 lastLaunched = launchedValid && std::isfinite(launchedValue)
        ? static_cast<qint64>(launchedValue)
        : 0;
    double frequencyScore = std::min(18.0, std::log2(count + 1.0) * 4.5);
    double recencyScore = 0.0;
    if (lastLaunched > 0) {
        const double age = std::max(0.0, static_cast<double>(now - lastLaunched));
        frequencyScore *= 0.55 + 0.45 * std::exp(-age / (90.0 * DayInMilliseconds));
        recencyScore = 10.0 * std::exp(-age / (14.0 * DayInMilliseconds));
    }
    return {std::min(MaximumUsageBoost, frequencyScore + recencyScore), count, lastLaunched};
}

int namePriority(const IndexedApplication &application, const PreparedQuery &query)
{
    if (application.name.normalized == query.normalized)
        return 0;
    if (application.name.normalized.startsWith(query.normalized))
        return 1;
    const bool everyTermStartsWord = std::all_of(query.terms.cbegin(), query.terms.cend(),
                                                  [&](const QString &term) {
        return std::any_of(application.name.words.cbegin(), application.name.words.cend(),
                           [&](const QString &word) { return word.startsWith(term); });
    });
    return everyTermStartsWord ? 1 : 2;
}

int cachedTermScore(const QString &term,
                    const PreparedText &text,
                    QHash<QString, int> &cache)
{
    const auto cached = cache.constFind(text.normalized);
    if (cached != cache.cend())
        return *cached;
    const int score = preparedTermScore(term, text);
    cache.insert(text.normalized, score);
    return score;
}

std::optional<Match> matchApplication(const IndexedApplication &application,
                                      const PreparedQuery &query,
                                      QVector<QHash<QString, int>> &termCaches,
                                      QHash<QString, int> &phraseCache)
{
    if (query.terms.isEmpty())
        return std::nullopt;

    double totalScore = 0.0;
    int worstScore = 0;
    for (qsizetype termIndex = 0; termIndex < query.terms.size(); ++termIndex) {
        const QString &term = query.terms.at(termIndex);
        int bestTermScore = NoMatch;
        for (const Field &field : application.fields) {
            const int fieldScore = cachedTermScore(term, field.text, termCaches[termIndex]);
            if (fieldScore < NoMatch)
                bestTermScore = std::min(bestTermScore, fieldScore + field.penalty);
        }
        if (bestTermScore >= NoMatch)
            return std::nullopt;
        totalScore += bestTermScore;
        worstScore = std::max(worstScore, bestTermScore);
    }

    double relevance = totalScore;
    if (query.terms.size() > 1) {
        relevance = totalScore / query.terms.size() + worstScore * 0.15;
        for (const Field &field : application.fields) {
            const int phraseScore = cachedTermScore(query.normalized, field.text, phraseCache);
            if (phraseScore < NoMatch)
                relevance = std::min(relevance, static_cast<double>(phraseScore + field.penalty));
        }
    }
    return Match{namePriority(application, query), relevance};
}

} // namespace

class LauncherSearchModel::Private
{
public:
    explicit Private(LauncherSearchModel *model)
        : q(model)
        , rankingTime(QDateTime::currentMSecsSinceEpoch())
    {
    }

    LauncherSearchModel *q;
    QVariantList applications;
    QString query;
    QVariantMap usageHistory;
    qint64 rankingTime;
    QVariantList results;
    QVector<IndexedApplication> index;

    void rebuildIndex()
    {
        index.clear();
        index.reserve(applications.size());
        for (const QVariant &entry : std::as_const(applications)) {
            const QString name = entryValue(entry, QStringLiteral("name")).toString();
            const PreparedText preparedName = prepareText(name);
            index.append({entry,
                          applicationKeyForEntry(entry),
                          preparedName,
                          applicationFields(entry, preparedName),
                          name,
                          entryValue(entry, QStringLiteral("id")).toString(),
                          {}});
        }
        rebuildUsage();
    }

    void rebuildUsage()
    {
        for (IndexedApplication &application : index)
            application.usage = usageData(application.key, usageHistory, rankingTime);
        rank();
    }

    void rank()
    {
        const PreparedQuery preparedQuery = prepareQuery(query);
        QVector<QHash<QString, int>> termCaches(preparedQuery.terms.size());
        for (QHash<QString, int> &cache : termCaches)
            cache.reserve(index.size() * 2);
        QHash<QString, int> phraseCache;
        phraseCache.reserve(index.size() * 2);
        QVector<RankedApplication> ranked;
        ranked.reserve(index.size());
        for (const IndexedApplication &application : std::as_const(index)) {
            if (preparedQuery.normalized.isEmpty()) {
                ranked.append({&application,
                               2,
                               0.0,
                               application.usage.boost,
                               application.usage.count,
                               application.usage.lastLaunched});
                continue;
            }
            const std::optional<Match> match = matchApplication(application,
                                                                preparedQuery,
                                                                termCaches,
                                                                phraseCache);
            if (!match)
                continue;
            ranked.append({&application,
                           match->priority,
                           match->relevance - application.usage.boost,
                           application.usage.boost,
                           application.usage.count,
                           application.usage.lastLaunched});
        }

        std::stable_sort(ranked.begin(), ranked.end(), [&](const RankedApplication &left,
                                                            const RankedApplication &right) {
            if (preparedQuery.normalized.isEmpty()) {
                if (left.usageCount != right.usageCount)
                    return left.usageCount > right.usageCount;
                if (left.lastLaunched != right.lastLaunched)
                    return left.lastLaunched > right.lastLaunched;
            } else {
                if (left.priority != right.priority)
                    return left.priority < right.priority;
                if (std::abs(left.score - right.score) > 0.0001)
                    return left.score < right.score;
                if (std::abs(left.usage - right.usage) > 0.0001)
                    return left.usage > right.usage;
            }
            const int nameComparison = QString::localeAwareCompare(left.application->sortName,
                                                                    right.application->sortName);
            if (nameComparison != 0)
                return nameComparison < 0;
            return QString::localeAwareCompare(left.application->sortId,
                                               right.application->sortId) < 0;
        });

        QVariantList nextResults;
        nextResults.reserve(ranked.size());
        for (const RankedApplication &match : std::as_const(ranked))
            nextResults.append(match.application->entry);
        results = std::move(nextResults);
        emit q->resultsChanged();
    }
};

LauncherSearchModel::LauncherSearchModel(QObject *parent)
    : QObject(parent)
    , d(std::make_unique<Private>(this))
{
}

LauncherSearchModel::~LauncherSearchModel() = default;

QVariantList LauncherSearchModel::applications() const
{
    return d->applications;
}

void LauncherSearchModel::setApplications(const QVariantList &applications)
{
    if (d->applications == applications)
        return;
    d->applications = applications;
    d->rebuildIndex();
    emit applicationsChanged();
}

QString LauncherSearchModel::query() const
{
    return d->query;
}

void LauncherSearchModel::setQuery(const QString &query)
{
    if (d->query == query)
        return;
    d->query = query;
    d->rank();
    emit queryChanged();
}

QVariantMap LauncherSearchModel::usageHistory() const
{
    return d->usageHistory;
}

void LauncherSearchModel::setUsageHistory(const QVariantMap &history)
{
    if (d->usageHistory == history)
        return;
    d->usageHistory = history;
    d->rebuildUsage();
    emit usageHistoryChanged();
}

qint64 LauncherSearchModel::rankingTime() const
{
    return d->rankingTime;
}

void LauncherSearchModel::setRankingTime(qint64 time)
{
    if (d->rankingTime == time)
        return;
    d->rankingTime = time;
    d->rebuildUsage();
    emit rankingTimeChanged();
}

QVariantList LauncherSearchModel::results() const
{
    return d->results;
}

QString LauncherSearchModel::applicationKey(const QVariant &application)
{
    return applicationKeyForEntry(application);
}

int LauncherSearchModel::boundedEditDistance(const QString &left,
                                             const QString &right,
                                             int limit)
{
    return ::boundedEditDistance(left, right, std::max(0, limit));
}
