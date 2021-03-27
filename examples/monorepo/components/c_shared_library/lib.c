#include <stdio.h>
#include "lib.h"
#include "sub_lib.h"

void hello(void) {
    printf("Hello!\n");
    sub_hello();
}
