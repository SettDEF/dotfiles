#!/usr/bin/env python3
"""Exit 0 when the OpenGL driver can draw a see-through window (a window format with alpha),
1 when it cannot. Unknown (no Wayland, no EGL) counts as yes.

Intel Haswell and older (Mesa crocus) offer none: every transparent pixel of the shell
(a popup's shadow margin, rounded corners) was drawn black."""
import ctypes
import sys
from ctypes import byref, c_int, c_uint, c_void_p

try:
    wl = ctypes.CDLL("libwayland-client.so.0")
    egl = ctypes.CDLL("libEGL.so.1")
except OSError:
    sys.exit(0)
wl.wl_display_connect.restype = c_void_p
wl.wl_display_connect.argtypes = [c_void_p]
egl.eglGetPlatformDisplay.restype = c_void_p
egl.eglGetPlatformDisplay.argtypes = [c_uint, c_void_p, c_void_p]
egl.eglInitialize.argtypes = [c_void_p, c_void_p, c_void_p]
egl.eglChooseConfig.argtypes = [c_void_p, c_void_p, c_void_p, c_int, c_void_p]

display = wl.wl_display_connect(None)
if not display:
    sys.exit(0)
EGL_PLATFORM_WAYLAND_KHR = 0x31D8
dpy = egl.eglGetPlatformDisplay(EGL_PLATFORM_WAYLAND_KHR, display, None)
if not dpy or not egl.eglInitialize(dpy, None, None):
    sys.exit(0)
# a window, OpenGL ES 2, 8 bits of alpha
attribs = (c_int * 7)(0x3033, 0x4, 0x3040, 0x4, 0x3021, 8, 0x3038)
count = c_int(0)
egl.eglChooseConfig(dpy, attribs, None, 0, byref(count))
sys.exit(0 if count.value else 1)
