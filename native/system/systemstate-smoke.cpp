#include "systemstatehub.h"

#include <QCoreApplication>
#include <QTextStream>
#include <QTimer>

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    SystemStateHub state;
    QTimer::singleShot(1000, &application, [&] {
        QTextStream output(stdout);
        output << "MEO_SYSTEM_STATE"
               << " networkAvailable=" << state.networkAvailable()
               << " networkConnected=" << state.networkConnected()
               << " wirelessEnabled=" << state.wirelessEnabled()
               << " networkName=" << state.networkName()
               << " bluetoothAvailable=" << state.bluetoothAvailable()
               << " bluetoothEnabled=" << state.bluetoothEnabled()
               << " batteryAvailable=" << state.batteryAvailable()
               << " batteryPercent=" << state.batteryPercent()
               << " audioAvailable=" << state.audioAvailable()
               << " volumePercent=" << state.volumePercent()
               << " audioDevice=" << state.audioDevice()
               << '\n';
        application.quit();
    });
    return application.exec();
}
