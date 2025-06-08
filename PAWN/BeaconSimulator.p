/*
Управление выходом устройства по BLE.
Для проверки работы скрипта необходимо установить на телефон програму Beacon Simulator.
*/

#include <time>
#include tracker
#include ble

#pragma dynamic 32

#define COMMAND_CLOSE_DOOR 1
#define COMMAND_OPEN_DOOR  2

main()
    settimer 1000 /* interval is in milliseconds */

@timer()
{
  new Command

  if (getbleid(0, Command)) /* Получить номер метки в канале 0 и использовать его как команду */
  {
    if (Command == COMMAND_OPEN_DOOR)
    {
      setout(0, false, true) /* Выключить выход. Записть состояние в EEPROM */
    }
    if (Command == COMMAND_CLOSE_DOOR)
    {
      setout(0, true, true); /* Включить выход. Записть состояние в EEPROM */
    }
  }
}

