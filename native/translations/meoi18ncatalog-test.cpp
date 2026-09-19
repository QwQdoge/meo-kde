#include <KLocalizedString>

#include <QTest>

class MeoI18nCatalogTest : public QObject
{
    Q_OBJECT

private slots:
    void resolvesSimplifiedChineseFromTheKdeCatalog()
    {
        KLocalizedString::setApplicationDomain("meo-desktop");
        KLocalizedString::addDomainLocaleDir("meo-desktop",
                                             QStringLiteral(MEO_I18N_LOCALE_DIR));
        QVERIFY(KLocalizedString::languages().contains(QStringLiteral("zh_CN")));

        QCOMPARE(i18nd("meo-desktop", "Meo Quick Settings"),
                 QStringLiteral("Meo 快速设置"));
        QCOMPARE(i18nd("meo-desktop", "%1 unread notifications", 3),
                 QStringLiteral("3 条未读通知"));
        QCOMPARE(i18nd("meo-desktop", "Dismiss notification"),
                 QStringLiteral("关闭通知"));
        QCOMPARE(i18nd("meo-desktop", "Wi-Fi is not available."),
                 QStringLiteral("Wi-Fi 不可用。"));
        QCOMPARE(i18nd("meo-desktop", "Brightness display is no longer available."),
                 QStringLiteral("显示器亮度控制已不可用。"));
        QCOMPARE(i18nd("meo-desktop", "The media player did not respond in time."),
                 QStringLiteral("媒体播放器未及时响应。"));
        QCOMPARE(i18nd("meo-desktop", "This widget is not in the Meo widget registry."),
                 QStringLiteral("此小组件不在 Meo 小组件注册表中。"));
        QCOMPARE(i18nd("meo-desktop", "Meo clock"), QStringLiteral("Meo 时钟"));
        QCOMPARE(i18nd("meo-desktop", "Current-session MPRIS controls with bounded local artwork."),
                 QStringLiteral("当前会话的 MPRIS 控制，使用受限的本地封面图。"));
        QCOMPARE(i18nd("meo-desktop", "Signing out in %1 seconds", 15),
                 QStringLiteral("将在 15 秒后退出登录"));
        QCOMPARE(i18nd("meo-desktop", "Partly cloudy"),
                 QStringLiteral("局部多云"));
        QCOMPARE(i18nd("meo-desktop", "Weather cache is invalid."),
                 QStringLiteral("天气缓存无效。"));
    }

    void retainsEnglishWhenTheDesktopLanguageIsEnglish()
    {
        KLocalizedString::setLanguages({QStringLiteral("en")});

        QCOMPARE(i18nd("meo-desktop", "Meo Quick Settings"),
                 QStringLiteral("Meo Quick Settings"));
        QCOMPARE(i18nd("meo-desktop", "Dismiss notification"),
                 QStringLiteral("Dismiss notification"));
        QCOMPARE(i18nd("meo-desktop", "Partly cloudy"),
                 QStringLiteral("Partly cloudy"));
    }
};

QTEST_GUILESS_MAIN(MeoI18nCatalogTest)

#include "meoi18ncatalog-test.moc"
