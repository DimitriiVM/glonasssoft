/*
Пример опроса состояния входа и 
отправки sms по изменению
*/

#include <time>
#include tracker
#include modem

#pragma dynamic 16

static bool: stat = false;

main()
    settimer 1000 /* Запускаем таймер с периодом 1000 миллисекунд */

@timer()
{
    if (getstate() != stat) /* Читаем состояние входа in0 и сравниваем с преведущим */
    {
        /* Если состояние отличаеться */
        stat = !stat; // Инвертируем запомненое состояние
        if (stat) // В зависимости от нового состояния передаем sms сообщения
        {
            sendsms("in 0 on");
        }
        else
        {
            sendsms("in 0 off");
        }
    }
}

