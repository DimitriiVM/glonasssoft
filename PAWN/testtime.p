#include <time>

#pragma dynamic 128

main()
    settimer 1000 /* interval is in milliseconds */

@timer()
{
    new hour, minute, second, year, month, day
    
    printf("timer 1000")
    printf("unix time %d", gettime(hour, minute, second))
    printf("year day  %d", getdate(year, month, day))
    printf("H:M:S %d:%d:%d Y:M:D %d:%d:%d", hour, minute, second, year, month, day)
}

