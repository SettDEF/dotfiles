#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>
#include <time.h>
#include <libevdev-1.0/libevdev/libevdev.h>
#include <X11/Xlib.h>
#include <math.h>
#include <string.h>

// Configurable parameters
#define BASE_ACCELERATION 1.3     // Increased for faster response
#define INERTIA_DECAY 0.98        // Increased for longer scrolling duration (3 seconds)
#define MAX_VELOCITY 5000         // Increased for faster maximum speed
#define POLL_RATE 5000            // Update interval in microseconds (5000 = 200Hz)
#define SCROLL_STEP_MULTIPLIER 4  // Increased for more pixels per tick

// Physics state
typedef struct {
    float velocity;
    int direction;
    long last_event_time;
    Display *xdisplay;
    Window xwindow;
} ScrollState;

long get_time_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

void send_scroll_event(ScrollState *state, int steps) {
    XEvent event;
    memset(&event, 0, sizeof(event));
    
    event.type = ButtonPress;
    event.xbutton.button = (state->direction > 0) ? Button4 : Button5;
    event.xbutton.same_screen = True;
    
    for(int i = 0; i < abs(steps); i++) {
        XSendEvent(state->xdisplay, state->xwindow, True, ButtonPressMask, &event);
        XFlush(state->xdisplay);
        event.type = ButtonRelease;
        XSendEvent(state->xdisplay, state->xwindow, True, ButtonReleaseMask, &event);
        XFlush(state->xdisplay);
        event.type = ButtonPress;
    }
}

void update_physics(ScrollState *state) {
    long current_time = get_time_ms();
    float delta_time = (current_time - state->last_event_time) / 1000.0f;
    
    // Apply inertia decay when no new events
    if(delta_time > 0.005f) {
        state->velocity *= pow(INERTIA_DECAY, delta_time * 60);
        if(fabs(state->velocity) < 10.0f) state->velocity = 0;
    }

    // Send scroll events proportional to current velocity
    if(state->velocity != 0) {
        int steps = (int)(state->velocity * delta_time * SCROLL_STEP_MULTIPLIER);
        if(steps != 0) {
            send_scroll_event(state, steps);
        }
    }
}

void handle_scroll_event(ScrollState *state, int value) {
    long now = get_time_ms();
    float delta_time = (now - state->last_event_time) / 1000.0f;
    
    // Reset velocity on direction change
    if((value > 0 && state->direction < 0) || (value < 0 && state->direction > 0)) {
        state->velocity = 0;
    }
    
    state->direction = (value > 0) ? 1 : -1;
    state->last_event_time = now;

    // Calculate acceleration based on input frequency
    float acceleration = BASE_ACCELERATION / fmaxf(delta_time, 0.001f);
    state->velocity += acceleration * state->direction;
    
    // Velocity clamping
    if(fabs(state->velocity) > MAX_VELOCITY) {
        state->velocity = MAX_VELOCITY * state->direction;
    }
}

int main() {
    ScrollState state = {0};
    state.xdisplay = XOpenDisplay(NULL);
    if(!state.xdisplay) {
        fprintf(stderr, "Failed to open X display\n");
        return EXIT_FAILURE;
    }
    state.xwindow = DefaultRootWindow(state.xdisplay);

    // Auto-detect mouse device
    int fd = -1;
    for(int i = 0; i < 16; i++) {
        char path[256];
        snprintf(path, sizeof(path), "/dev/input/event%d", i);
        fd = open(path, O_RDONLY | O_NONBLOCK);
        if(fd >= 0) {
            struct libevdev *dev;
            if(libevdev_new_from_fd(fd, &dev) == 0) {
                if(libevdev_has_event_type(dev, EV_REL) && 
                   libevdev_has_event_code(dev, EV_REL, REL_WHEEL)) {
                    printf("Using device: %s\n", libevdev_get_name(dev));
                    break;
                }
                libevdev_free(dev);
            }
            close(fd);
            fd = -1;
        }
    }

    if(fd < 0) {
        fprintf(stderr, "No suitable mouse device found\n");
        XCloseDisplay(state.xdisplay);
        return EXIT_FAILURE;
    }

    struct libevdev *dev;
    libevdev_new_from_fd(fd, &dev);

    struct input_event ev;
    while(1) {
        // Process input events
        while(libevdev_next_event(dev, LIBEVDEV_READ_FLAG_NORMAL, &ev) == 0) {
            if(ev.type == EV_REL && ev.code == REL_WHEEL) {
                handle_scroll_event(&state, ev.value);
            }
        }
        
        // Update physics simulation
        update_physics(&state);
        
        // Sleep to prevent CPU hogging
        usleep(POLL_RATE);
    }

    libevdev_free(dev);
    close(fd);
    XCloseDisplay(state.xdisplay);
    return EXIT_SUCCESS;
}
