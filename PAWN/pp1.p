/*
Скрипт по чтению параметров с 4-х датчиков ПП-01
Пример работы с последовательным портом на реальном оборудовании
Пример подключения пользовательских библиотек "modbus.inc" и "crc.inc"
*/
#include <time>
#include <string>
#include tracker
#include serial
#include modbus
#include crc

#pragma dynamic       128
#define COUNT_PP1     4

#define COUNTER_ENTERED_TAG 0
#define COUNTER_OUT_TAG     1
#define STATE_DOOR_TAG      2

/*
Функция чтения параметров ПП-01
*/
bool: ReadPP1(Addr, &CountEntered, &CountOut, &StatDoor)
{
  new Buff[16]
  new Len, Crc

  /* Формируем запрос на чтение */
  Buff[0] = 0x11 /* Начало запроса */
  Buff[1] = (Addr & 0xFF)  /* Адресс */
  Buff[2] = 0x01 /* Запрос нпа чтение данных */
  Crc = calc_crc8(Buff,3)
  Buff[3] = Crc
  /* Передаем запрос */
  rssend(Buff, 4)
  /* Читаем ответ */
  Len = rsrecv(Buff, 15, 1000, 10)
  if (Len == 9 && check_crc8(Buff, Len) && Buff[0] == 0x1E && Buff[1] == Addr)
  {
    CountEntered = (Buff[3] & 0xFF) + ((Buff[4] & 0xFF) << 8)  /* Счетчик вошедших пассажиров */
    CountOut = (Buff[5] & 0xFF) + ((Buff[6]& 0xFF) << 8)  /* Счетчик вышедших пассажиров */
    StatDoor = Buff[7]
    return true
  }
  return false
}

/* Скрипт */
main()
{
  new CountEntered[COUNT_PP1];
  new CountOut[COUNT_PP1];
  new StatDoor[COUNT_PP1];
  new OldStatDoor[COUNT_PP1];

  new bool:Valid
  new bool:isEvent
  new Addr
  new i
  isEvent = false

  for (i = 0; i < COUNT_PP1; i++)
  {
    CountEntered[i] = 0
    CountOut[i] = 0
    StatDoor[i] = 0
    OldStatDoor[i] = 0xFF
  }

  for (;;)
  {
    if (rsopen()) /* Пытаемся открыть порт */
    {
      Addr = 0;
      for (i = 0; i < COUNT_PP1; i++)
      {
        Addr = i + 1
        /* Читаем ПП-01 */
        Valid = ReadPP1(Addr, CountEntered[i], CountOut[i], StatDoor[i])
        settag(COUNTER_ENTERED_TAG + (i*3), CountEntered[i], Valid)
        settag(COUNTER_OUT_TAG + (i*3), CountOut[i], Valid)
        settag(STATE_DOOR_TAG + (i*3), StatDoor[i], Valid)
        /* Проверяем на изменение статуса двери */
        if ((Valid == true) && (OldStatDoor[i] != StatDoor[i]))
        {
          isEvent = true
          OldStatDoor[i] = StatDoor[i];
        }
        if(Valid == false)
        {
          OldStatDoor[i] = 0xFF;
        }
      }
      /* Если установлен флаг события */
      if (isEvent)
      {
        pushpoint();
        isEvent = false
      }
      rsclose() /* Закрываем если не нужен */
    }
    delay(1000)
  }
}
