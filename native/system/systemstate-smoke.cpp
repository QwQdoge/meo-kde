#include "systemstatehub.h"
#include "platformcontroller.h"
#include "mediacontroller.h"

#include <QCoreApplication>
#include <QTextStream>
#include <QTimer>

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    SystemStateHub state;
    PlatformController platform;
    MediaController media;
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
               << " audioOutputs=" << state.audioOutputDevices().size()
               << " microphoneAvailable=" << state.microphoneAvailable()
               << " microphoneDevice=" << state.microphoneDevice()
               << " audioInputs=" << state.audioInputDevices().size()
               << " brightnessAvailable=" << platform.brightnessAvailable()
               << " brightnessDisplays=" << platform.brightnessDisplays().size()
               << " nightLightAvailable=" << platform.nightLightAvailable()
               << " powerProfilesAvailable=" << platform.powerProfilesAvailable()
               << " activePowerProfile=" << platform.activePowerProfile()
               << " mediaAvailable=" << media.available()
               << " mediaPlayer=" << media.playerName()
               << '\n';
        application.quit();
    });
    return application.exec();
}
