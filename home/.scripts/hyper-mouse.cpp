#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <atomic>
#include <mutex>
#include <algorithm>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <sys/select.h>
#include <linux/uinput.h>
#include <libevdev/libevdev.h>
#include <libevdev/libevdev-uinput.h>

struct CurveConfig {
    std::string type = "sigmoid"; // "linear", "exponential", "sigmoid", "bezier"
    float smoothness = 0.35f;      // Low-pass EMA alpha (0.05 = super smooth, 1.0 = raw)
    float sensitivity = 1.0f;     // Overall gain
    float tremor_friction = 0.4f; // Micro-tremor friction threshold
    float exp_power = 1.4f;       // Power for exponential curve
    float sigmoid_mid = 12.0f;    // Midpoint velocity for S-curve
    float sigmoid_steep = 0.2f;   // Steepness of S-curve transition
    float p1x = 0.2f, p1y = 0.1f; // Cubic Bezier control point 1
    float p2x = 0.7f, p2y = 0.9f; // Cubic Bezier control point 2
    bool enabled = true;
};

// Global state
static CurveConfig g_config;
static std::mutex g_config_mutex;
static std::atomic<bool> g_running{true};

static std::string get_config_path() {
    const char* home = getenv("HOME");
    std::string path = home ? std::string(home) + "/.config/hyper-mouse.json" : "/tmp/hyper-mouse.json";
    return path;
}

static std::string get_status_path() {
    return "/dev/shm/hyper-mouse-status.json";
}

void write_status_file() {
    std::lock_guard<std::mutex> lock(g_config_mutex);
    std::string status = "{\n";
    status += "  \"enabled\": " + std::string(g_config.enabled ? "true" : "false") + ",\n";
    status += "  \"type\": \"" + g_config.type + "\",\n";
    status += "  \"smoothness\": " + std::to_string(g_config.smoothness) + ",\n";
    status += "  \"sensitivity\": " + std::to_string(g_config.sensitivity) + ",\n";
    status += "  \"tremor_friction\": " + std::to_string(g_config.tremor_friction) + "\n";
    status += "}\n";

    std::string tmp_path = get_status_path() + ".tmp";
    std::ofstream out(tmp_path);
    if (out.is_open()) {
        out << status;
        out.close();
        rename(tmp_path.c_str(), get_status_path().c_str());
    }
}

// Parametric Cubic Bezier evaluation
static float evaluate_bezier(float t, float p0, float p1, float p2, float p3) {
    float u = 1.0f - t;
    float tt = t * t;
    float uu = u * u;
    float uuu = uu * u;
    float ttt = tt * t;

    return uuu * p0 + 3.0f * uu * t * p1 + 3.0f * u * tt * p2 + ttt * p3;
}

// Compute multiplier from input speed
static float calculate_gain(float speed, const CurveConfig& cfg) {
    if (!cfg.enabled) return 1.0f;
    if (speed < 0.001f) return 0.0f;

    // Apply micro-tremor damping at very low speeds
    if (speed < cfg.tremor_friction) {
        float factor = speed / cfg.tremor_friction;
        return factor * factor; // Quadratic dampening
    }

    if (cfg.type == "linear") {
        return cfg.sensitivity;
    } else if (cfg.type == "exponential") {
        return cfg.sensitivity * std::pow(speed, cfg.exp_power - 1.0f);
    } else if (cfg.type == "sigmoid") {
        float sig = 1.0f / (1.0f + std::exp(-cfg.sigmoid_steep * (speed - cfg.sigmoid_mid)));
        return cfg.sensitivity * (0.8f + 1.2f * sig);
    } else if (cfg.type == "bezier") {
        float norm_speed = std::clamp(speed / 50.0f, 0.0f, 1.0f);
        float curve_y = evaluate_bezier(norm_speed, 0.0f, cfg.p1y, cfg.p2y, 1.0f);
        return cfg.sensitivity * (curve_y / (norm_speed + 0.001f));
    }

    return cfg.sensitivity;
}

// Motion smoothing & output calculation
struct MotionFilter {
    float smooth_dx = 0.0f;
    float smooth_dy = 0.0f;
    float acc_dx = 0.0f;
    float acc_dy = 0.0f;

    void process(float raw_dx, float raw_dy, int& out_dx, int& out_dy) {
        CurveConfig cfg;
        {
            std::lock_guard<std::mutex> lock(g_config_mutex);
            cfg = g_config;
        }

        if (!cfg.enabled) {
            out_dx = static_cast<int>(raw_dx);
            out_dy = static_cast<int>(raw_dy);
            return;
        }

        // 1. Low-Pass EMA Filter
        float alpha = std::clamp(cfg.smoothness, 0.05f, 1.0f);
        smooth_dx = alpha * raw_dx + (1.0f - alpha) * smooth_dx;
        smooth_dy = alpha * raw_dy + (1.0f - alpha) * smooth_dy;

        // 2. Velocity calculation
        float speed = std::sqrt(smooth_dx * smooth_dx + smooth_dy * smooth_dy);
        float gain = calculate_gain(speed, cfg);

        // 3. Scale velocity
        float target_dx = smooth_dx * gain + acc_dx;
        float target_dy = smooth_dy * gain + acc_dy;

        // 4. Sub-pixel accumulator integer rounding
        out_dx = static_cast<int>(std::round(target_dx));
        out_dy = static_cast<int>(std::round(target_dy));

        // 5. Save sub-pixel remainder
        acc_dx = target_dx - out_dx;
        acc_dy = target_dy - out_dy;
    }
};

std::string find_mouse_device() {
    std::ifstream devices("/proc/bus/input/devices");
    if (!devices.is_open()) return "";

    std::string line, current_dev, event_path;
    bool is_mouse = false;

    while (std::getline(devices, line)) {
        if (line.rfind("N: Name=", 0) == 0) {
            if (line.find("HyperSmooth") != std::string::npos) {
                is_mouse = false;
                continue;
            }
            if (line.find("Mouse") != std::string::npos || line.find("mouse") != std::string::npos || line.find("b034") != std::string::npos) {
                is_mouse = true;
            } else {
                is_mouse = false;
            }
        } else if (is_mouse && line.rfind("H: Handlers=", 0) == 0) {
            size_t pos = line.find("event");
            if (pos != std::string::npos) {
                std::string ev = line.substr(pos);
                size_t space = ev.find(' ');
                if (space != std::string::npos) ev = ev.substr(0, space);
                return "/dev/input/" + ev;
            }
        }
    }
    return "";
}

int create_uinput_device(struct libevdev** out_dev, struct libevdev_uinput** out_uidev) {
    struct libevdev* dev = libevdev_new();
    libevdev_set_name(dev, "HyperSmooth Virtual Mouse");

    libevdev_enable_event_type(dev, EV_KEY);
    libevdev_enable_event_code(dev, EV_KEY, BTN_LEFT, NULL);
    libevdev_enable_event_code(dev, EV_KEY, BTN_RIGHT, NULL);
    libevdev_enable_event_code(dev, EV_KEY, BTN_MIDDLE, NULL);
    libevdev_enable_event_code(dev, EV_KEY, BTN_SIDE, NULL);
    libevdev_enable_event_code(dev, EV_KEY, BTN_EXTRA, NULL);

    libevdev_enable_event_type(dev, EV_REL);
    libevdev_enable_event_code(dev, EV_REL, REL_X, NULL);
    libevdev_enable_event_code(dev, EV_REL, REL_Y, NULL);
    libevdev_enable_event_code(dev, EV_REL, REL_WHEEL, NULL);
    libevdev_enable_event_code(dev, EV_REL, REL_HWHEEL, NULL);
    libevdev_enable_event_code(dev, EV_REL, REL_WHEEL_HI_RES, NULL);

    int err = libevdev_uinput_create_from_device(dev, LIBEVDEV_UINPUT_OPEN_MANAGED, out_uidev);
    if (err < 0) {
        libevdev_free(dev);
        return err;
    }
    *out_dev = dev;
    return 0;
}

void run_daemon() {
    std::cout << "[HyperSmooth] C++20 Motion Daemon Starting..." << std::endl;

    std::string mouse_path = find_mouse_device();
    if (mouse_path.empty()) {
        std::cerr << "[HyperSmooth] Error: No physical mouse device found in /proc/bus/input/devices" << std::endl;
        return;
    }
    std::cout << "[HyperSmooth] Reading raw mouse events from: " << mouse_path << std::endl;

    int input_fd = open(mouse_path.c_str(), O_RDONLY | O_NONBLOCK);
    if (input_fd < 0) {
        std::cerr << "[HyperSmooth] Failed to open " << mouse_path << ": " << strerror(errno) << std::endl;
        return;
    }

    struct libevdev* in_dev = NULL;
    if (libevdev_new_from_fd(input_fd, &in_dev) < 0) {
        std::cerr << "[HyperSmooth] Failed to initialize libevdev for input device" << std::endl;
        close(input_fd);
        return;
    }

    struct libevdev* out_dev = NULL;
    struct libevdev_uinput* uidev = NULL;
    if (create_uinput_device(&out_dev, &uidev) < 0) {
        std::cerr << "[HyperSmooth] Failed to create virtual uinput device" << std::endl;
        libevdev_free(in_dev);
        close(input_fd);
        return;
    }
    std::cout << "[HyperSmooth] Virtual mouse created: " << libevdev_uinput_get_devnode(uidev) << std::endl;

    write_status_file();

    MotionFilter filter;
    int raw_dx = 0, raw_dy = 0;

    while (g_running) {
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(input_fd, &fds);
        struct timeval tv = {0, 10000}; // 10ms timeout

        int sel = select(input_fd + 1, &fds, NULL, NULL, &tv);
        if (sel > 0 && FD_ISSET(input_fd, &fds)) {
            struct input_event ev;
            while (libevdev_next_event(in_dev, LIBEVDEV_READ_FLAG_NORMAL, &ev) == LIBEVDEV_READ_STATUS_SUCCESS) {
                if (ev.type == EV_REL) {
                    if (ev.code == REL_X) raw_dx += ev.value;
                    else if (ev.code == REL_Y) raw_dy += ev.value;
                    else {
                        libevdev_uinput_write_event(uidev, ev.type, ev.code, ev.value);
                    }
                } else if (ev.type == EV_SYN && ev.code == SYN_REPORT) {
                    if (raw_dx != 0 || raw_dy != 0) {
                        int out_dx = 0, out_dy = 0;
                        filter.process(static_cast<float>(raw_dx), static_cast<float>(raw_dy), out_dx, out_dy);

                        if (out_dx != 0) libevdev_uinput_write_event(uidev, EV_REL, REL_X, out_dx);
                        if (out_dy != 0) libevdev_uinput_write_event(uidev, EV_REL, REL_Y, out_dy);
                        raw_dx = 0;
                        raw_dy = 0;
                    }
                    libevdev_uinput_write_event(uidev, EV_SYN, SYN_REPORT, 0);
                } else {
                    libevdev_uinput_write_event(uidev, ev.type, ev.code, ev.value);
                }
            }
        }
    }

    libevdev_uinput_destroy(uidev);
    libevdev_free(out_dev);
    libevdev_free(in_dev);
    close(input_fd);
}

int main(int argc, char* argv[]) {
    if (argc > 1) {
        std::string arg = argv[1];
        if (arg == "--daemon") {
            run_daemon();
            return 0;
        } else if (arg == "--status") {
            std::ifstream in(get_status_path());
            if (in.is_open()) {
                std::cout << in.rdbuf();
            } else {
                std::cout << "{\"enabled\": false}" << std::endl;
            }
            return 0;
        }
    }

    std::cout << "Usage: hyper-mouse --daemon | --status" << std::endl;
    return 0;
}
