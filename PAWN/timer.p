/*
Пример работы с таймером
*/

#include <tracker>
#include <time>

#pragma dynamic 32

new CountEventTimer = 0; // Счетчик событий

main()
{
    settimer(1000) // Запускаем таймер с периодом 1 сек
}

@timer()
{
    CountEventTimer++; // Увеличиваем значение счетчика событий таймера
    printf("Timer event #%d", CountEventTimer) // Выводи в отладочный вывод
    printf("Русский текст")
}
