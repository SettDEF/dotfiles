#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <pwd.h>

int main() {
    char cwd[1024];
    struct passwd *pw = getpwuid(getuid());
    if (pw == NULL) {
        perror("getpwuid");
        exit(1);
    }

    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        perror("getcwd");
        exit(1);
    }

    printf("%s@%s %s %%# ", pw->pw_name, getenv("HOSTNAME"), cwd);
    return 0;
}
