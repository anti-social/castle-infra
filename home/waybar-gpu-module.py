"""
AMD GPU Sysfs Monitor (Optimized)
Uses persistent file handles to avoid repeated open/close overhead.
Reads VRAM, GPU load, temperature, and power from Linux sysfs and ints JSON periodically.

Usage: python amd_gpu_monitor.py /sys/class/drm/card0/device
Permissions: May require root or user in 'video' group for hwmon (temp/power) reads.
Python: 3.6+
"""

import sys
import os
import json
import time


class AMDGpuMonitor:
    def __init__(self, sysfs_path):
        self.base = sysfs_path.rstrip('/')
        self._readers = []
        self._initialize_readers()

    def _initialize_readers(self):
        """Define what to read, where, and how to convert units."""
        self._add_reader('mem_total', os.path.join(self.base, 'mem_info_vram_total'), 
                         lambda v: int(v) / (1024**2))
        self._add_reader('mem_used', os.path.join(self.base, 'mem_info_vram_used'), 
                         lambda v: int(v) / (1024**2))
        self._add_reader('gpu_load', os.path.join(self.base, 'gpu_busy_percent'), 
                         lambda v: int(v))

        hwmon_dir = self._detect_hwmon_dir(os.path.join(self.base, 'hwmon'))
        if os.path.isdir(hwmon_dir):
            self._add_hwmon_reader(hwmon_dir, 'temp', lambda v: round(int(v) / 1000.0, 1))
            self._add_hwmon_reader(hwmon_dir, 'power', lambda v: round(int(v) / 1000000.0, 2))

        # Open all handles
        for r in self._readers:
            self._open_handle(r)

    def _add_reader(self, key, path, convert):
        self._readers.append({
            'key': key,
            'path': path,
            'convert': convert,
            'handle': None
        })

    def _detect_hwmon_dir(self, base_hwmon_dir):
        try:
            dirs = os.listdir(base_hwmon_dir)
            if not dirs:
                return None
            return os.path.join(base_hwmon_dir, dirs[0]) 
        except OSError:
            pass

    def _add_hwmon_reader(self, hwmon_dir, prefix, convert):
        try:
            files = os.listdir(hwmon_dir)
            target = None
            # Prefer standard _input suffix
            for f in files:
                if f.startswith(prefix) and (f.endswith('_input') or f.endswith('_average')):
                    target = f
                    break
            if not target:
                for f in files:
                    if f.startswith(prefix):
                        target = f
                        break
            if target:
                self._add_reader(
                    f'{prefix}_celsius' if prefix == 'temp' else f'{prefix}_watts',
                    os.path.join(hwmon_dir, target),
                    convert
                )
        except OSError:
            pass

    def _open_handle(self, reader):
        try:
            reader['handle'] = open(reader['path'], 'r')
        except OSError:
            reader['handle'] = None

    def read(self):
        """Read all metrics using persistent handles. Recovers stale handles automatically."""
        metrics = {}
        stale_handles = []

        for r in self._readers:
            if r['handle'] is None:
                self._open_handle(r)
                if r['handle'] is None:
                    continue

            try:
                r['handle'].seek(0)
                val_str = r['handle'].read().strip()
                if val_str:
                    converted = r['convert'](val_str)
                    metrics[r['key']] = converted
                else:
                    # Empty read indicates stale handle
                    stale_handles.append(r)
            except (ValueError, OSError):
                stale_handles.append(r)

        # Reopen stale handles for the next cycle
        for r in stale_handles:
            self._open_handle(r)

        # Calculate derived memory stats
        if 'mem_total' in metrics and 'mem_used' in metrics:
            total = metrics['mem_total']
            used = metrics['mem_used']
            if total > 0:
                metrics['memory_total'] = round(total)
                metrics['memory_used'] = round(used)
                metrics['memory_used_percent'] = round((used / total) * 100, 1)
                # Clean up raw values
                metrics.pop('mem_total', None)
                metrics.pop('mem_used', None)

        return metrics


def main():
    if len(sys.argv) < 2:
        print("Usage: python waybar-gpu-module.py <sysfs_path>", file=sys.stderr)
        print("Example: python waybar-gpu-module.py /sys/class/drm/card0/device", file=sys.stderr)
        sys.exit(1)

    sysfs_path = sys.argv[1]
    if not os.path.isdir(sysfs_path):
        print(f"Error: '{sysfs_path}' is not a valid directory.", file=sys.stderr)
        sys.exit(1)

    monitor = AMDGpuMonitor(sysfs_path)
    interval = 2.0  # seconds between reads

    try:
        while True:
            metrics = monitor.read()
            # print(metrics)
            print(json.dumps({
                "text": (
                    f"VRAM {metrics['memory_used_percent']:.0f}% "
                    f"GPU {metrics['gpu_load']}% "
                    f"{metrics['temp_celsius']:.0f}°C "
                    f"{metrics['power_watts']:.0f}W"
                )
            }), flush=True)
            time.sleep(interval)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
