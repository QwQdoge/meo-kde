pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configPath: Quickshell.env("MEO_SESSION_ENTRY_CONFIG") ?? ""

    property bool valid: false
    property string source: "safe-fallback"
    property string lastError: ""

    property string clockStyle: "large"
    property bool showDate: true
    property string backgroundTreatment: "dim"
    property string wallpaperMode: "follow-desktop"
    property var wallpaper: ({ source: "system-default", assetId: "", fillMode: "cover" })

    property bool mediaEnabled: false
    property bool weatherEnabled: false
    property bool audioEnabled: false
    property string weatherCity: ""

    property string notificationVisibility: "hidden"
    property bool showAlbumArtwork: false
    property string weatherLocation: "hidden"

    property string activeAuthenticationScreen: "auto"
    property var displayOverrides: []
    property string reduceMotion: "system"

    function isObject(value: var): bool {
        return value !== null && typeof value === "object" && !Array.isArray(value);
    }

    function hasExactKeys(object: var, keys: var): bool {
        if (!isObject(object))
            return false;
        const actual = Object.keys(object).sort();
        const expected = keys.slice().sort();
        if (actual.length !== expected.length)
            return false;
        for (let i = 0; i < actual.length; ++i) {
            if (actual[i] !== expected[i])
                return false;
        }
        return true;
    }

    function isBoolean(value: var): bool {
        return typeof value === "boolean";
    }

    function isString(value: var, maximumLength: int): bool {
        if (typeof value !== "string" || value.length > maximumLength)
            return false;
        return !/[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]/.test(value);
    }

    function isEnum(value: var, allowed: var): bool {
        return typeof value === "string" && allowed.includes(value);
    }

    function isSafeAssetId(value: var): bool {
        if (!isString(value, 256) || !/^[A-Za-z0-9][A-Za-z0-9._/-]{0,255}$/.test(value))
            return false;
        const segments = value.split("/");
        return segments.every(segment => segment.length > 0 && segment !== "." && segment !== "..");
    }

    function validateWallpaper(value: var): bool {
        if (!hasExactKeys(value, ["source", "assetId", "fillMode"]))
            return false;
        if (!isEnum(value.source, ["system-default", "current-user", "managed-asset"]))
            return false;
        if (!isEnum(value.fillMode, ["cover", "contain", "stretch", "center"]))
            return false;
        if (value.source === "system-default")
            return value.assetId === "";
        return isSafeAssetId(value.assetId);
    }

    function validateAppearance(value: var): bool {
        if (!hasExactKeys(value, ["clockStyle", "showDate", "backgroundTreatment", "wallpaperMode", "wallpaper"]))
            return false;
        return isEnum(value.clockStyle, ["large", "compact"])
            && isBoolean(value.showDate)
            && isEnum(value.backgroundTreatment, ["dim", "blur", "solid"])
            && isEnum(value.wallpaperMode, ["follow-desktop", "managed"])
            && validateWallpaper(value.wallpaper);
    }

    function validateModules(value: var): bool {
        if (!hasExactKeys(value, ["media", "weather", "audio", "weatherCity"]))
            return false;
        return isBoolean(value.media)
            && isBoolean(value.weather)
            && isBoolean(value.audio)
            && isString(value.weatherCity, 96);
    }

    function validatePrivacy(value: var): bool {
        if (!hasExactKeys(value, ["notificationVisibility", "showAlbumArtwork", "weatherLocation"]))
            return false;
        return isEnum(value.notificationVisibility, ["hidden", "count", "app-name", "full-content"])
            && isBoolean(value.showAlbumArtwork)
            && isEnum(value.weatherLocation, ["hidden", "city", "precise"]);
    }

    function validateLayout(value: var): bool {
        if (!hasExactKeys(value, ["activeAuthenticationScreen", "displayOverrides"]))
            return false;
        if (!isEnum(value.activeAuthenticationScreen, ["auto", "fixed-primary", "follow-interaction"]))
            return false;
        if (!Array.isArray(value.displayOverrides) || value.displayOverrides.length > 16)
            return false;

        const seen = new Set();
        for (const override of value.displayOverrides) {
            if (!hasExactKeys(override, ["outputKey", "wallpaper"]))
                return false;
            if (!isString(override.outputKey, 256) || override.outputKey.length === 0 || seen.has(override.outputKey))
                return false;
            if (!validateWallpaper(override.wallpaper))
                return false;
            seen.add(override.outputKey);
        }
        return true;
    }

    function validateMotion(value: var): bool {
        return hasExactKeys(value, ["reduceMotion"])
            && isEnum(value.reduceMotion, ["system", "always", "never"]);
    }

    function validateDocument(document: var): bool {
        if (!hasExactKeys(document,
                          ["schemaVersion", "scope", "appearance", "modules", "privacy", "layout", "motion"]))
            return false;
        if (document.schemaVersion !== 1 || document.scope !== "lockscreen")
            return false;
        return validateAppearance(document.appearance)
            && validateModules(document.modules)
            && validatePrivacy(document.privacy)
            && validateLayout(document.layout)
            && validateMotion(document.motion);
    }

    function applyDocument(document: var): void {
        root.clockStyle = document.appearance.clockStyle;
        root.showDate = document.appearance.showDate;
        root.backgroundTreatment = document.appearance.backgroundTreatment;
        root.wallpaperMode = document.appearance.wallpaperMode;
        root.wallpaper = document.appearance.wallpaper;

        root.mediaEnabled = document.modules.media;
        root.weatherEnabled = document.modules.weather;
        root.audioEnabled = document.modules.audio;
        root.weatherCity = document.modules.weatherCity;

        root.notificationVisibility = document.privacy.notificationVisibility;
        root.showAlbumArtwork = document.privacy.showAlbumArtwork;
        root.weatherLocation = document.privacy.weatherLocation;

        root.activeAuthenticationScreen = document.layout.activeAuthenticationScreen;
        root.displayOverrides = document.layout.displayOverrides;
        root.reduceMotion = document.motion.reduceMotion;

        root.valid = true;
        root.source = "user-config";
        root.lastError = "";
    }

    function useProductDefaults(): void {
        root.clockStyle = "large";
        root.showDate = true;
        root.backgroundTreatment = "dim";
        root.wallpaperMode = "follow-desktop";
        root.wallpaper = ({ source: "system-default", assetId: "", fillMode: "cover" });
        root.mediaEnabled = true;
        root.weatherEnabled = true;
        root.audioEnabled = true;
        root.weatherCity = "";
        root.notificationVisibility = "count";
        root.showAlbumArtwork = false;
        root.weatherLocation = "city";
        root.activeAuthenticationScreen = "auto";
        root.displayOverrides = [];
        root.reduceMotion = "system";
        root.valid = true;
        root.source = "product-defaults";
        root.lastError = "";
    }

    function failClosed(message: string): void {
        root.clockStyle = "large";
        root.showDate = true;
        root.backgroundTreatment = "dim";
        root.wallpaperMode = "follow-desktop";
        root.wallpaper = ({ source: "system-default", assetId: "", fillMode: "cover" });
        root.mediaEnabled = false;
        root.weatherEnabled = false;
        root.audioEnabled = false;
        root.weatherCity = "";
        root.notificationVisibility = "hidden";
        root.showAlbumArtwork = false;
        root.weatherLocation = "hidden";
        root.activeAuthenticationScreen = "auto";
        root.displayOverrides = [];
        root.reduceMotion = "always";
        root.valid = false;
        root.source = "safe-fallback";
        root.lastError = message;
    }

    function parse(text: string): void {
        if (text.length > 64 * 1024) {
            failClosed("Session-entry configuration is too large");
            return;
        }

        let document;
        try {
            document = JSON.parse(text);
        } catch (error) {
            failClosed("Session-entry configuration is not valid JSON");
            return;
        }
        if (!validateDocument(document)) {
            failClosed("Session-entry configuration failed validation");
            return;
        }
        applyDocument(document);
    }

    FileView {
        id: configFile

        path: root.configPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.useProductDefaults();
            else
                root.failClosed("Session-entry configuration cannot be read");
        }
    }

    Component.onCompleted: {
        if (!root.configPath)
            root.failClosed("Session-entry configuration path is unavailable");
    }
}
