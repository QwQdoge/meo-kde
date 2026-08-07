/****************************************************************************
** Meta object code from reading C++ file 'systemstatehub.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../../../native/system/systemstatehub.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'systemstatehub.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN14SystemStateHubE_t {};
} // unnamed namespace

template <> constexpr inline auto SystemStateHub::qt_create_metaobjectdata<qt_meta_tag_ZN14SystemStateHubE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "SystemStateHub",
        "networkChanged",
        "",
        "bluetoothChanged",
        "batteryChanged",
        "audioChanged",
        "networkAvailable",
        "networkConnected",
        "wirelessEnabled",
        "networkName",
        "networkStatus",
        "bluetoothAvailable",
        "bluetoothEnabled",
        "batteryAvailable",
        "batteryPercent",
        "batteryCharging",
        "audioAvailable",
        "volumePercent",
        "audioMuted",
        "audioDevice"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'networkChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'bluetoothChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'batteryChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'audioChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'networkAvailable'
        QtMocHelpers::PropertyData<bool>(6, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'networkConnected'
        QtMocHelpers::PropertyData<bool>(7, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'wirelessEnabled'
        QtMocHelpers::PropertyData<bool>(8, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 0),
        // property 'networkName'
        QtMocHelpers::PropertyData<QString>(9, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'networkStatus'
        QtMocHelpers::PropertyData<QString>(10, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'bluetoothAvailable'
        QtMocHelpers::PropertyData<bool>(11, QMetaType::Bool, QMC::DefaultPropertyFlags, 1),
        // property 'bluetoothEnabled'
        QtMocHelpers::PropertyData<bool>(12, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'batteryAvailable'
        QtMocHelpers::PropertyData<bool>(13, QMetaType::Bool, QMC::DefaultPropertyFlags, 2),
        // property 'batteryPercent'
        QtMocHelpers::PropertyData<int>(14, QMetaType::Int, QMC::DefaultPropertyFlags, 2),
        // property 'batteryCharging'
        QtMocHelpers::PropertyData<bool>(15, QMetaType::Bool, QMC::DefaultPropertyFlags, 2),
        // property 'audioAvailable'
        QtMocHelpers::PropertyData<bool>(16, QMetaType::Bool, QMC::DefaultPropertyFlags, 3),
        // property 'volumePercent'
        QtMocHelpers::PropertyData<int>(17, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'audioMuted'
        QtMocHelpers::PropertyData<bool>(18, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'audioDevice'
        QtMocHelpers::PropertyData<QString>(19, QMetaType::QString, QMC::DefaultPropertyFlags, 3),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<SystemStateHub, qt_meta_tag_ZN14SystemStateHubE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject SystemStateHub::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14SystemStateHubE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14SystemStateHubE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN14SystemStateHubE_t>.metaTypes,
    nullptr
} };

void SystemStateHub::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<SystemStateHub *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->networkChanged(); break;
        case 1: _t->bluetoothChanged(); break;
        case 2: _t->batteryChanged(); break;
        case 3: _t->audioChanged(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (SystemStateHub::*)()>(_a, &SystemStateHub::networkChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemStateHub::*)()>(_a, &SystemStateHub::bluetoothChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemStateHub::*)()>(_a, &SystemStateHub::batteryChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemStateHub::*)()>(_a, &SystemStateHub::audioChanged, 3))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->networkAvailable(); break;
        case 1: *reinterpret_cast<bool*>(_v) = _t->networkConnected(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->wirelessEnabled(); break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->networkName(); break;
        case 4: *reinterpret_cast<QString*>(_v) = _t->networkStatus(); break;
        case 5: *reinterpret_cast<bool*>(_v) = _t->bluetoothAvailable(); break;
        case 6: *reinterpret_cast<bool*>(_v) = _t->bluetoothEnabled(); break;
        case 7: *reinterpret_cast<bool*>(_v) = _t->batteryAvailable(); break;
        case 8: *reinterpret_cast<int*>(_v) = _t->batteryPercent(); break;
        case 9: *reinterpret_cast<bool*>(_v) = _t->batteryCharging(); break;
        case 10: *reinterpret_cast<bool*>(_v) = _t->audioAvailable(); break;
        case 11: *reinterpret_cast<int*>(_v) = _t->volumePercent(); break;
        case 12: *reinterpret_cast<bool*>(_v) = _t->audioMuted(); break;
        case 13: *reinterpret_cast<QString*>(_v) = _t->audioDevice(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 2: _t->setWirelessEnabled(*reinterpret_cast<bool*>(_v)); break;
        case 6: _t->setBluetoothEnabled(*reinterpret_cast<bool*>(_v)); break;
        case 11: _t->setVolumePercent(*reinterpret_cast<int*>(_v)); break;
        case 12: _t->setAudioMuted(*reinterpret_cast<bool*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *SystemStateHub::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *SystemStateHub::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14SystemStateHubE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int SystemStateHub::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 4)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 4;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 4)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 4;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 14;
    }
    return _id;
}

// SIGNAL 0
void SystemStateHub::networkChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void SystemStateHub::bluetoothChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void SystemStateHub::batteryChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void SystemStateHub::audioChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}
QT_WARNING_POP
