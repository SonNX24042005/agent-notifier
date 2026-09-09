const {Gio, GLib, Meta} = imports.gi;
const Main = imports.ui.main;

const BUS_NAME = 'io.github.sonnx24042005.AiAgentNotifier';
const OBJECT_PATH = '/io/github/sonnx24042005/AiAgentNotifier';
let INSTANCE_ID = '';
const INTERFACE_XML = `
<node>
  <interface name="io.github.sonnx24042005.AiAgentNotifier">
    <method name="FocusWindow">
      <arg type="u" name="callerPid" direction="in"/>
      <arg type="s" name="projectHint" direction="in"/>
      <arg type="s" name="titleFingerprint" direction="in"/>
      <arg type="b" name="focused" direction="out"/>
    </method>
    <method name="FocusWindowV2">
      <arg type="u" name="callerPid" direction="in"/>
      <arg type="s" name="projectHint" direction="in"/>
      <arg type="s" name="titleFingerprint" direction="in"/>
      <arg type="s" name="appHint" direction="in"/>
      <arg type="b" name="focused" direction="out"/>
    </method>
    <method name="IsWindowActive">
      <arg type="u" name="callerPid" direction="in"/>
      <arg type="s" name="projectHint" direction="in"/>
      <arg type="s" name="titleFingerprint" direction="in"/>
      <arg type="s" name="appHint" direction="in"/>
      <arg type="b" name="active" direction="out"/>
    </method>
    <method name="CaptureActiveWindow">
      <arg type="u" name="callerPid" direction="in"/>
      <arg type="s" name="projectHint" direction="in"/>
      <arg type="s" name="appHint" direction="in"/>
      <arg type="s" name="windowToken" direction="out"/>
    </method>
    <method name="FocusWindowById">
      <arg type="s" name="windowToken" direction="in"/>
      <arg type="b" name="focused" direction="out"/>
    </method>
    <method name="IsWindowActiveById">
      <arg type="s" name="windowToken" direction="in"/>
      <arg type="b" name="active" direction="out"/>
    </method>
  </interface>
</node>`;

const DEVELOPER_CLASSES = [
    'code', 'vscodium', 'cursor', 'windsurf', 'antigravity', 'zed',
    'chatgpt', 'codex',
    'gnome-terminal', 'org.gnome.terminal', 'tilix', 'alacritty', 'kitty', 'wezterm', 'konsole',
    'ptyxis', 'kgx', 'pycharm', 'idea', 'clion', 'webstorm', 'goland',
    'phpstorm', 'rider', 'rubymine', 'datagrip', 'fleet', 'sublime_text',
    'gedit', 'kate', 'emacs', 'neovim', 'gvim',
];

function normalize(value) {
    return String(value || '').trim().toLowerCase().replace(/\s+/g, ' ');
}

function titlesCompatible(expected, current) {
    const expectedTitle = normalize(expected);
    const currentTitle = normalize(current);
    if (!expectedTitle || !currentTitle)
        return false;
    return expectedTitle === currentTitle ||
        expectedTitle.includes(currentTitle) || currentTitle.includes(expectedTitle);
}

function readParentPid(pid) {
    try {
        const [ok, contents] = GLib.file_get_contents(`/proc/${pid}/status`);
        if (!ok)
            return 0;
        const text = imports.byteArray.toString(contents);
        const match = text.match(/^PPid:\s+(\d+)$/m);
        return match ? Number.parseInt(match[1], 10) : 0;
    } catch (_error) {
        return 0;
    }
}

function isPidInAncestry(targetPid, startPid) {
    const target = Number(targetPid) || 0;
    let current = Number(startPid) || 0;
    const seen = new Set();
    while (current > 1 && !seen.has(current) && seen.size < 32) {
        if (current === target)
            return true;
        seen.add(current);
        current = readParentPid(current);
    }
    return false;
}

function isDeveloperWindow(window) {
    const wmClass = normalize(window.get_wm_class());
    let appId = '';
    try {
        appId = normalize(window.get_gtk_application_id());
    } catch (_error) {
        appId = '';
    }
    return DEVELOPER_CLASSES.some(item => wmClass.includes(item) || appId.includes(item));
}

function isSupportedWindow(window) {
    if (!window || window.is_skip_taskbar())
        return false;
    const windowType = window.get_window_type();
    return windowType === Meta.WindowType.NORMAL ||
        windowType === Meta.WindowType.DIALOG ||
        windowType === Meta.WindowType.MODAL_DIALOG;
}

function appIdentity(window) {
    let appId = '';
    try {
        appId = normalize(window.get_gtk_application_id());
    } catch (_error) {
        appId = '';
    }
    return `${normalize(window.get_wm_class())} ${appId}`;
}

function matchesAppHint(window, appHint) {
    const sourceApp = normalize(appHint);
    const identity = appIdentity(window);
    if (sourceApp === 'antigravity')
        return identity.includes('antigravity');
    if (sourceApp === 'codex')
        return ['chatgpt', 'codex']
            .some(item => identity.includes(item));
    return false;
}

function targetMatchStrength(window, callerPid, projectHint, titleFingerprint, appHint) {
    if (!isSupportedWindow(window) || !isDeveloperWindow(window))
        return 0;

    const title = normalize(window.get_title());
    const hint = normalize(projectHint);
    const titleMatches = Boolean(hint && title.includes(hint)) ||
        titlesCompatible(titleFingerprint, title);
    const pidMatches = isPidInAncestry(window.get_pid(), callerPid);

    if (pidMatches)
        return 3;
    if (titleMatches)
        return 2;
    return matchesAppHint(window, appHint) ? 1 : 0;
}

function matchesTarget(window, callerPid, projectHint, titleFingerprint, appHint) {
    return targetMatchStrength(window, callerPid, projectHint, titleFingerprint, appHint) > 0;
}

function windowToken(window) {
    if (!window || typeof window.get_stable_sequence !== 'function')
        return '';
    const sequence = Number(window.get_stable_sequence());
    return INSTANCE_ID && Number.isInteger(sequence) && sequence > 0
        ? `gnome:${INSTANCE_ID}:${sequence}`
        : '';
}

function findWindowByToken(token) {
    const matches = global.get_window_actors()
        .map(actor => actor.get_meta_window())
        .filter(window => isSupportedWindow(window) &&
            isDeveloperWindow(window) && windowToken(window) === token);
    return matches.length === 1 ? matches[0] : null;
}

class AiAgentNotifierWindowFocus {
    enable() {
        // Keep window tokens valid across disable/enable in the same Shell.
        if (!global.aiAgentNotifierWindowNamespace)
            global.aiAgentNotifierWindowNamespace = GLib.uuid_string_random();
        INSTANCE_ID = global.aiAgentNotifierWindowNamespace;
        this._ownerId = Gio.bus_own_name(
            Gio.BusType.SESSION,
            BUS_NAME,
            Gio.BusNameOwnerFlags.NONE,
            connection => {
                this._dbusObject = Gio.DBusExportedObject.wrapJSObject(INTERFACE_XML, this);
                this._dbusObject.export(connection, OBJECT_PATH);
            },
            null,
            null
        );
    }

    disable() {
        if (this._dbusObject) {
            this._dbusObject.flush();
            this._dbusObject.unexport();
            this._dbusObject = null;
        }
        if (this._ownerId) {
            Gio.bus_unown_name(this._ownerId);
            this._ownerId = 0;
        }
        INSTANCE_ID = '';
    }

    _focusWindow(callerPid, projectHint, titleFingerprint, appHint) {
        const scoredCandidates = global.get_window_actors()
            .map(actor => actor.get_meta_window())
            .map(window => ({
                window,
                strength: targetMatchStrength(window, callerPid, projectHint, titleFingerprint, appHint),
            }))
            .filter(candidate => candidate.strength > 0);

        const bestStrength = scoredCandidates.reduce(
            (best, candidate) => Math.max(best, candidate.strength),
            0
        );
        const candidates = scoredCandidates.filter(candidate => candidate.strength === bestStrength);

        if (candidates.length !== 1)
            return false;

        Main.activateWindow(candidates[0].window, global.get_current_time());
        return true;
    }

    FocusWindow(callerPid, projectHint, titleFingerprint) {
        return this._focusWindow(callerPid, projectHint, titleFingerprint, '');
    }

    FocusWindowV2(callerPid, projectHint, titleFingerprint, appHint) {
        return this._focusWindow(callerPid, projectHint, titleFingerprint, appHint);
    }

    IsWindowActive(callerPid, projectHint, titleFingerprint, appHint) {
        let activeWindow = null;
        try {
            activeWindow = global.display.get_focus_window();
        } catch (_error) {
            activeWindow = global.display.focus_window || null;
        }
        return matchesTarget(activeWindow, callerPid, projectHint, titleFingerprint, appHint);
    }

    CaptureActiveWindow(callerPid, projectHint, appHint) {
        let activeWindow = null;
        try {
            activeWindow = global.display.get_focus_window();
        } catch (_error) {
            activeWindow = global.display.focus_window || null;
        }
        if (targetMatchStrength(activeWindow, callerPid, projectHint, '', appHint) <= 0)
            return '';
        return windowToken(activeWindow);
    }

    FocusWindowById(token) {
        const window = findWindowByToken(normalize(token));
        if (!window)
            return false;
        Main.activateWindow(window, global.get_current_time());
        return true;
    }

    IsWindowActiveById(token) {
        let activeWindow = null;
        try {
            activeWindow = global.display.get_focus_window();
        } catch (_error) {
            activeWindow = global.display.focus_window || null;
        }
        return Boolean(activeWindow && windowToken(activeWindow) === normalize(token));
    }
}

function init() {
    return new AiAgentNotifierWindowFocus();
}
