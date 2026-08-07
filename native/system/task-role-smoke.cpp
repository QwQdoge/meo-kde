#include <taskmanager/tasksmodel.h>

#include <QGuiApplication>
#include <QTextStream>
#include <QTimer>

int main(int argc, char **argv)
{
    QGuiApplication application(argc, argv);
    TaskManager::TasksModel model;
    QTimer::singleShot(1000, &application, [&] {
        QTextStream output(stdout);
        const auto roles = model.roleNames();
        for (auto iterator = roles.cbegin(); iterator != roles.cend(); ++iterator) {
            output << iterator.key() << '=' << iterator.value() << '\n';
        }
        application.quit();
    });
    return application.exec();
}
