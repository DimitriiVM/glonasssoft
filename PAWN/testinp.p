/* 
Пример чтения значения входа
и управления выходом
*/
#include <time>
#include tracker

#define ADC_SETPOINT  12000
#define COUNTER_LIMIT 20

static bool: State = false // Состояние управляющего статуса
static Counter = 0

main()
  settimer 100 /* interval is in milliseconds */

@timer()
{
  new bool: NewEvent = false

  // Filter
  if (getinput() >= ADC_SETPOINT) // Если значение на входе in 0 превышает  12000
  {
    if (Counter < COUNTER_LIMIT) // Если значение счетчика превышений меньше 20
      Counter++ // Увеличиваем счетчик
    else if (!State) // Иначе, если состояние управляющего статуса false 
    {
      State = true // Устанавливаем статус равным true
      NewEvent = true // Устанавливаем флаг события что состояние входа нужно изменить 
    }
  }
  else // Иначе
  {
    if (Counter) // Уменьшаем счетчик превышения
      Counter--
    else if (State) // Если состояние управляющего статуса true 
    {
      State = false // Устанавливаем статус равным афдыу
      NewEvent = true // Устанавливаем флаг события что состояние входа нужно изменить 
    }
  }

  // Set output
  if (NewEvent) // Если установлен флаг события
  {
    setout(0, State); // Состояние выхода устанавливаем равным управляющему статусу 
  }
}

