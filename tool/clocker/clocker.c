//#include "stdint.h"
#include "stdio.h"
#include "math.h"
//#include "float.h"


void coordinate(int hand, double angle, double radius) {
    long int x = lround(cos(angle) * radius);
    long int y = lround(sin(angle) * radius);
    
    printf("%3d  %f X = %ld Y = %ld\n", hand, angle, x, y);
}

int main() {
    const double pi = acos(-1);
    const double step = 2 * pi / 60;
    const double radius = 20.0;

    printf("CLOCKER:\n");
    for (int clock_hand = 0; clock_hand < 60; clock_hand++) {
        coordinate(clock_hand, step * clock_hand, radius);
    }
    return 0;
}
