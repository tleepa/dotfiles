#! /usr/bin/env python3

import argparse
import dbus
import time


def parse_duration(duration: str) -> int:
    if duration[-1] in ["s", "m", "h"]:
        duration_unit = duration[-1]
        duration_value = int(duration[:-1])
    else:
        duration_unit = "s"
        duration_value = int(duration)

    if duration_unit == "s":
        duration_seconds = duration_value
    if duration_unit == "m":
        duration_seconds = duration_value * 60
    if duration_unit == "h":
        duration_seconds = duration_value * 3600

    return duration_seconds


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "duration",
        help="how long should screen lock be disabled; use values with units (e.g., 30s, 5m, 1h)",
        type=str,
        default="5m",
    )
    parser.add_argument("-d", "--debug", action="store_true", help="debug info")
    return parser.parse_args(argv)


def main() -> None:
    try:
        args = parse_args()
        duration_sec = parse_duration(args.duration)

        if args.debug:
            print(f"disable lock for          = {args.duration}")
            print(f"disable lock for seconds  = {duration_sec}")

        bus = dbus.SessionBus()

        notifier = bus.get_object(
            "org.freedesktop.Notifications", "/org/freedesktop/Notifications"
        )
        notifier_iface = dbus.Interface(
            notifier, dbus_interface="org.freedesktop.Notifications"
        )

        saver = bus.get_object("org.freedesktop.ScreenSaver", "/ScreenSaver")
        saver_interface = dbus.Interface(
            saver, dbus_interface="org.freedesktop.ScreenSaver"
        )

        # inhibit the screensaver
        cookie = saver_interface.Inhibit("user", "disable screen lock on demand")

        timeout_start = time.time()
        interval = 60
        while time.time() - timeout_start < duration_sec:
            elapsed = time.time() - timeout_start
            if (duration_sec - elapsed) // interval == 0:
                sleep_more = round((duration_sec - elapsed) % interval)
            else:
                sleep_more = interval

            notifier_iface.Notify(
                "Reminder",
                0,
                "",
                "Disabled screen lock in progress!",
                "",
                [],
                {"urgency": 1},
                10000,
            )

            if args.debug:
                print(f"sleep for next seconds    = {sleep_more}")

            time.sleep(sleep_more)

        # restore
        saver_interface.UnInhibit(cookie)

    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f"Error: {e}\n")


if __name__ == "__main__":
    main()
