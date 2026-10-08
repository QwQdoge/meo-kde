pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string cachePath: Quickshell.env("MEO_LOCKSCREEN_WEATHER_CACHE") ?? ""
    readonly property int maximumAgeMs: 6 * 60 * 60 * 1000

    property bool available: false
    property bool stale: true
    property string temperatureText: ""
    property string condition: ""
    property string apparentTemperatureText: ""
    property string highTemperatureText: ""
    property string lowTemperatureText: ""
    property string location: ""
    property string updatedAt: ""
    property var forecast: []
    property string lastError: ""

    function boundedText(value: var, maximumLength: int): string {
        if (typeof value !== "string")
            return "";
        return value
            .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f\u202a-\u202e\u2066-\u2069]/g, "")
            .slice(0, maximumLength)
            .trim();
    }

    function finiteTemperature(value: var): bool {
        return typeof value === "number" && Number.isFinite(value) && value >= -100 && value <= 100;
    }

    function formatTemperature(value: var, unit: string): string {
        if (!finiteTemperature(value))
            return "";
        const rounded = Math.abs(value - Math.round(value)) < 0.05
            ? Math.round(value).toString()
            : value.toFixed(1);
        return `${rounded}°${unit}`;
    }

    function clear(message: string): void {
        root.available = false;
        root.stale = true;
        root.temperatureText = "";
        root.condition = "";
        root.apparentTemperatureText = "";
        root.highTemperatureText = "";
        root.lowTemperatureText = "";
        root.location = "";
        root.updatedAt = "";
        root.forecast = [];
        root.lastError = message;
    }

    function parse(text: string): void {
        if (text.length > 64 * 1024) {
            clear("Weather cache is too large");
            return;
        }

        let object;
        try {
            object = JSON.parse(text);
        } catch (error) {
            clear("Weather cache is not valid JSON");
            return;
        }

        if (object === null || typeof object !== "object" || Array.isArray(object)
            || object.schemaVersion !== 1) {
            clear("Weather cache has an unsupported schema");
            return;
        }

        const timestamp = Date.parse(object.updatedAt);
        const now = Date.now();
        const unit = typeof object.unit === "string" ? object.unit.toUpperCase() : "";
        const condition = boundedText(object.condition, 96);
        if (!Number.isFinite(timestamp) || timestamp > now + 5 * 60 * 1000
            || !finiteTemperature(object.temperature)
            || (unit !== "C" && unit !== "F") || !condition) {
            clear("Weather cache failed validation");
            return;
        }

        const age = now - timestamp;
        if (age > root.maximumAgeMs) {
            clear("Weather cache is stale");
            root.updatedAt = object.updatedAt;
            return;
        }

        const entries = [];
        if (Array.isArray(object.forecast)) {
            for (let index = 0; index < object.forecast.length && entries.length < 6; ++index) {
                const item = object.forecast[index];
                if (item === null || typeof item !== "object" || Array.isArray(item))
                    continue;
                const time = boundedText(item.time, 32);
                const precipitation = item.precipitationChance;
                if (time.length < 16 || !finiteTemperature(item.temperature)
                    || typeof precipitation !== "number" || !Number.isInteger(precipitation)
                    || precipitation < 0 || precipitation > 100)
                    continue;
                entries.push({
                    time: time.slice(11, 16),
                    temperatureText: formatTemperature(item.temperature, unit),
                    precipitationChance: precipitation
                });
            }
        }

        root.available = true;
        root.stale = false;
        root.temperatureText = formatTemperature(object.temperature, unit);
        root.condition = condition;
        root.apparentTemperatureText = formatTemperature(object.apparentTemperature, unit);
        root.highTemperatureText = formatTemperature(object.dailyHigh, unit);
        root.lowTemperatureText = formatTemperature(object.dailyLow, unit);
        root.location = boundedText(object.location, 64);
        root.updatedAt = object.updatedAt;
        root.forecast = entries;
        root.lastError = "";
    }

    FileView {
        id: cacheFile

        path: root.cachePath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: root.clear("Weather cache is unavailable")
    }

    // This timer re-validates a local cache only. The lock surface never starts
    // a network request; cache production belongs to the separate refresher.
    Timer {
        running: root.cachePath.length > 0
        repeat: true
        interval: 60 * 1000
        onTriggered: cacheFile.reload()
    }

    Component.onCompleted: {
        if (!root.cachePath)
            root.clear("Weather cache path is unavailable");
    }
}
