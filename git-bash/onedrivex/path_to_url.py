"""Convert a local OneDrive-synced path to its web URL on Windows."""

from __future__ import annotations

import argparse
import ctypes
import os
import subprocess
import sys
import time
from typing import Any, Iterable, List, NamedTuple, Optional
from urllib.parse import quote

try:
    import winreg
except ImportError:  # pragma: no cover - only reached outside Windows
    winreg = None  # type: ignore


class SyncRoot(NamedTuple):
    local_path: str
    url_namespace: str


class GraphError(RuntimeError):
    pass


def _registry_string(key: Any, name: str) -> Optional[str]:
    try:
        value, _ = winreg.QueryValueEx(key, name)
    except OSError:
        return None
    return value if isinstance(value, str) and value else None


def _read_sync_roots(key: Any) -> List[SyncRoot]:
    roots = []
    mount_point = _registry_string(key, "MountPoint")
    url_namespace = _registry_string(key, "UrlNamespace")
    if mount_point and url_namespace:
        roots.append(
            SyncRoot(os.path.expandvars(mount_point), url_namespace.rstrip("/"))
        )

    index = 0
    while True:
        try:
            child_name = winreg.EnumKey(key, index)
        except OSError:
            break
        index += 1
        try:
            with winreg.OpenKey(key, child_name) as child_key:
                roots.extend(_read_sync_roots(child_key))
        except OSError:
            continue
    return roots


def get_onedrive_sync_roots() -> List[SyncRoot]:
    """Return OneDrive local-to-remote mappings registered for this user."""
    if winreg is None:
        raise RuntimeError("OneDrive path detection is supported only on Windows")

    registry_path = r"Software\SyncEngines\Providers\OneDrive"
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, registry_path) as key:
            roots = _read_sync_roots(key)
    except OSError:
        return []

    return list(dict.fromkeys(roots))


def path_to_onedrive_url(
    local_path: str, sync_roots: Optional[Iterable[SyncRoot]] = None
) -> Optional[str]:
    """Return the web URL for local_path, or None when it is not in OneDrive."""
    path = os.path.realpath(
        os.path.abspath(os.path.expanduser(os.path.expandvars(local_path)))
    )
    matches = []

    for root in sync_roots if sync_roots is not None else get_onedrive_sync_roots():
        mount_point = os.path.realpath(os.path.abspath(root.local_path))
        try:
            common_path = os.path.commonpath([path, mount_point])
            is_inside_root = os.path.normcase(common_path) == os.path.normcase(
                mount_point
            )
        except ValueError:
            is_inside_root = False
        if is_inside_root:
            matches.append((len(mount_point), mount_point, root.url_namespace))

    if not matches:
        return None

    _, mount_point, url_namespace = max(matches)
    relative_path = os.path.relpath(path, mount_point)
    if relative_path == ".":
        return url_namespace.rstrip("/")

    url_path = quote(relative_path.replace(os.sep, "/"), safe="/!$&'()*+,;=:@-._~")
    return "{}/{}".format(url_namespace.rstrip("/"), url_path)

def _native_popup_menus(desktop: Any, menu_class: Any) -> List[Any]:
    send_message = ctypes.windll.user32.SendMessageW
    send_message.restype = ctypes.c_ssize_t
    menus = []
    for popup in desktop.windows(class_name="#32768", visible_only=True):
        menu_handle = send_message(popup.handle, 0x01E1, 0, 0)
        if menu_handle:
            menus.append(
                menu_class(popup, menu_handle, is_main_menu=False)
            )
    return menus


def _native_menu_item(
    menus: Iterable[Any], title: str, starts_with: bool = False
) -> Any:
    for menu in reversed(list(menus)):
        for item in menu.items():
            item_title = item.text().replace("&", "").split("\t", 1)[0].strip()
            matches = item_title.casefold() == title.casefold()
            if starts_with:
                matches = item_title.casefold().startswith(title.casefold())
            if matches:
                return item
    raise RuntimeError("Explorer menu item {!r} was not found".format(title))


def _same_path(first: str, second: str) -> bool:
    return os.path.normcase(os.path.realpath(first)) == os.path.normcase(
        os.path.realpath(second)
    )


def _explorer_windows_at_paths(shell: Any, paths: Iterable[str]) -> List[Any]:
    from pywintypes import com_error

    matches = []
    paths = tuple(paths)
    for window in list(shell.Windows()):
        try:
            if os.path.basename(window.FullName).casefold() != "explorer.exe":
                continue
            folder_path = window.Document.Folder.Self.Path
            if any(_same_path(folder_path, path) for path in paths):
                matches.append(window)
        except (AttributeError, OSError, TypeError, com_error):
            continue
    return matches


def _close_explorer_windows(shell: Any, path: str, timeout: float = 5) -> None:
    paths = [os.path.dirname(path)]
    if os.path.isdir(path):
        paths.append(path)
    windows = _explorer_windows_at_paths(shell, paths)
    if not windows:
        return
    for window in windows:
        try:
            window.Quit()
        except Exception as error:
            raise RuntimeError("Could not close Explorer for: {}".format(path)) from error

    deadline = time.monotonic() + timeout
    while _explorer_windows_at_paths(shell, paths):
        if time.monotonic() >= deadline:
            raise RuntimeError("Explorer did not close for: {}".format(path))
        time.sleep(0.2)


def _selected_explorer_handle(shell: Any, path: str) -> Optional[int]:
    parent_path = os.path.dirname(path)
    for window in shell.Windows():
        try:
            folder_path = window.Document.Folder.Self.Path
            if not _same_path(folder_path, parent_path):
                continue
            selected_items = window.Document.SelectedItems()
            for index in range(selected_items.Count):
                if _same_path(selected_items.Item(index).Path, path):
                    return int(window.HWND)
        except (AttributeError, OSError, TypeError):
            continue
    return None


def _wait_for_clipboard_change(sequence: int, timeout: float = 15) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if ctypes.windll.user32.GetClipboardSequenceNumber() != sequence:
            return True
        time.sleep(0.2)
    return False


def _menu_navigation_keys(position: int, action: str) -> str:
    if position < 1:
        raise ValueError("Menu positions must be at least 1")
    down_keys = "{{DOWN {}}}".format(position - 1) if position > 1 else ""
    return "{HOME}" + down_keys + action


def _menu_navigation_from_end(up_count: int, action: str) -> str:
    if up_count < 0:
        raise ValueError("Menu up count cannot be negative")
    up_keys = "{{UP {}}}".format(up_count) if up_count else ""
    return "{END}" + up_keys + action


def copy_link_via_explorer(
    local_path: str,
    one_drive_up_count: int = 3,
    copy_link_position: int = 2,
) -> None:
    """Invoke Explorer's OneDrive > Copy link command for local_path."""
    try:
        from pywinauto import Desktop, keyboard  # type: ignore[reportMissingImports]
        from pywinauto.controls.menuwrapper import (  # type: ignore[reportMissingImports]
            Menu,
        )
        from win32com.client import Dispatch  # type: ignore[reportMissingImports]
    except ImportError as error:
        raise RuntimeError(
            "The --copy-link option requires pywinauto: "
            "python -m pip install -r requirements.txt"
        ) from error

    path = os.path.realpath(
        os.path.abspath(os.path.expanduser(os.path.expandvars(local_path)))
    )
    if not os.path.exists(path):
        raise RuntimeError("Path does not exist: {}".format(path))

    shell = Dispatch("Shell.Application")
    _close_explorer_windows(shell, path)
    subprocess.Popen('explorer.exe /n,/select,"{}"'.format(path))

    desktop = Desktop(backend="uia")
    native_desktop = Desktop(backend="win32")
    deadline = time.monotonic() + 10
    explorer_handle = None
    while time.monotonic() < deadline:
        explorer_handle = _selected_explorer_handle(shell, path)
        if explorer_handle is not None:
            break
        time.sleep(0.2)
    if explorer_handle is None:
        raise RuntimeError(
            "Explorer did not select the requested path: {}".format(path)
        )

    explorer_window = desktop.window(handle=explorer_handle).wrapper_object()
    explorer_window.set_focus()
    time.sleep(0.5)
    clipboard_sequence = ctypes.windll.user32.GetClipboardSequenceNumber()
    keyboard.send_keys("+{F10}")

    try:
        menu_deadline = time.monotonic() + 5
        one_drive = None
        while time.monotonic() < menu_deadline:
            try:
                one_drive = _native_menu_item(
                    _native_popup_menus(native_desktop, Menu),
                    "OneDrive",
                    starts_with=True,
                )
                break
            except RuntimeError:
                time.sleep(0.2)
        if one_drive is None:
            keyboard.send_keys(
                _menu_navigation_from_end(one_drive_up_count, "{RIGHT}"),
                pause=0.05,
            )
        else:
            one_drive.click_input()

        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                copy_link = _native_menu_item(
                    _native_popup_menus(native_desktop, Menu), "Copy link"
                )
            except RuntimeError:
                time.sleep(0.2)
                continue

            copy_link.click_input()
            if _wait_for_clipboard_change(clipboard_sequence):
                explorer_window.close()
                return
            raise RuntimeError(
                "OneDrive did not update the clipboard within 15 seconds"
            )

        keyboard.send_keys(
            _menu_navigation_keys(copy_link_position, "{ENTER}"),
            pause=0.05,
        )
        if _wait_for_clipboard_change(clipboard_sequence):
            explorer_window.close()
            return
        raise RuntimeError(
            "The clipboard did not change after moving up {} times from the end "
            "and OneDrive-submenu position {}; override them with "
            "--onedrive-menu-up and --copy-link-menu-position".format(
                one_drive_up_count, copy_link_position
            )
        )
    except Exception as error:
        keyboard.send_keys("{ESC}")
        if isinstance(error, RuntimeError):
            raise
        raise RuntimeError("Could not invoke OneDrive > Copy link: {}".format(error)) from error


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Return the web URL for a local OneDrive or SharePoint path."
    )
    parser.add_argument("path", help="Local file or directory path")
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument(
        "-s",
        "--copy-link",
        action="store_true",
        help="invoke OneDrive > Copy link in Explorer",
    )
    parser.add_argument(
        "--onedrive-menu-up",
        type=int,
        default=3,
        help="Up presses from the end of Explorer's context menu (default: 3)",
    )
    parser.add_argument(
        "--copy-link-menu-position",
        type=int,
        default=2,
        help="Copy link's 1-based position in the OneDrive submenu (default: 2)",
    )
    args = parser.parse_args()

    try:
        url = path_to_onedrive_url(args.path)
    except RuntimeError as error:
        parser.error(str(error))

    if url is None:
        print("Path is not inside a registered OneDrive sync root", file=sys.stderr)
        return 1

    if args.copy_link:
        try:
            copy_link_via_explorer(
                args.path,
                one_drive_up_count=args.onedrive_menu_up,
                copy_link_position=args.copy_link_menu_position,
            )
        except RuntimeError as error:
            print(str(error), file=sys.stderr)
            return 1
        print("OneDrive sharing URL is in the clipboard")
        return 0

    print(url)
    return 0


if __name__ == "__main__":
    sys.exit(main())