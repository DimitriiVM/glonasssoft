/*
Скрипт реализующий дополнительный функционал датчика угла наклона DU BLE.
Использование датчика угла как метки
*/

#include <string>
#include <time>
#include tracker
#include ble

#pragma dynamic 128

#define BAT_TAG             0 /* Напряжение на батарее */
#define RSSI_TAG            1 /* RSSI */
#define ANGLE_TAG           2 /* Текущий угол */
#define UPPER_ANGLE_TAG     3 /* Верхняя калибровка угла */
#define BUTTOM_ANGLE_TAG    4 /* Нижняя калибровка угла */
#define MODE_TAG            5 /* Режим */
#define EVENT_TAG           6 /* Событие */
#define TEMP_TAG            7 /* Температура */
#define ID_TAG              8 /* Идентификатор */

#define WAIT_TIME_LIMIT     90000 /* 90 секунд ждем пакеты, прежде чем говорить что метка не присылает данные */

new SaveMac[6]
new SaveRSSI

/* Функция проверяет, что MAC адрес изменился и уровень RSSI выше, чем у преведущего*/
bool: CheckAndSaveMac(mac[6], rssi)
{
  if (SaveMac == mac)
  {
    SaveRSSI = rssi
    return false;
  }
  if (SaveRSSI >=  rssi)
  {
    return false;
  }
  SaveMac = mac
  SaveRSSI = rssi
  return true;
}

/* Функция определяет, записывать данные или нет */
bool: isDataWrite(mac[6])
{
  if (SaveMac == mac)
  {
    return true;
  }
  return false;
}

bool: SetInvalid()
{
  SaveMac = [0, 0, 0, 0, 0, 0]
  SaveRSSI = -255
  settag(ID_TAG, 0, false);
  settag(RSSI_TAG, 0, false);
  settag(TEMP_TAG, 0, false);
  settag(BAT_TAG, 0, false);
  settag(ANGLE_TAG, 0, false);
  settag(UPPER_ANGLE_TAG, 0, false);
  settag(BUTTOM_ANGLE_TAG, 0, false);
  settag(MODE_TAG, 0, false);
  settag(EVENT_TAG, 0, false);
}

/* Запуск скрипта */
main()
{
  SetInvalid()
  bleadvertsubscribe()
}

/* Обработка пакета */
@bleadvertrecv0(mac[6], rssi, data[31], len)
{
  new lTemp; /* Температура */
  new lBat; /* Напряжение на батарее */
  new lAngle; /* Текущий угол */
  new lUpperAngle; /* Верхняя калибровка угла */
  new lButtomAngle; /* Нижняя калибровка угла */
  new lMode; /* Режим */
  new lEvent; /* Событие сработки */
  new bool:isEvent = false
  new lId = 0; /* 2 - 5 байт MAC адреса */

  /* Начало обработки */
  /* Валидация пакета по длине и типу */
  if ((len < 16) || (data[BLE_GAP_LEN_OFFS] < 15) || (data[BLE_GAP_TYPE_OFFS] != 0xFF)) return;
  /* Валидация Company ID */
  if ((data[BLE_GAP_DATA_OFFS + 0] != 0x16) || (data[BLE_GAP_DATA_OFFS + 1] != 0x0F)) return;
  /* Hardware ID */
  if (data[BLE_GAP_DATA_OFFS + 2] != 0x04) return;
  /* Полезные данные */
  lMode = data[BLE_GAP_DATA_OFFS + 3];
  lEvent = data[BLE_GAP_DATA_OFFS + 4];
  lAngle = (data[BLE_GAP_DATA_OFFS + 6] << 8) | data[BLE_GAP_DATA_OFFS + 5];
  lTemp = data[BLE_GAP_DATA_OFFS + 7];
  lUpperAngle = (data[BLE_GAP_DATA_OFFS + 8] << 8) | data[BLE_GAP_DATA_OFFS + 9];
  lButtomAngle = (data[BLE_GAP_DATA_OFFS + 10] << 8) | data[BLE_GAP_DATA_OFFS +11];
  lBat = data[BLE_GAP_DATA_OFFS + 12];
  lId = (mac[2] << 24) | (mac[3] << 16) | (mac[4] << 8) | mac[5]
  printf("MAC=%x:%x:%x:%x:%x:%x,RSSI=%d", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5], rssi)
  printf("ESCDU.Angle=%d,Upper=%d,Buttom=%d,Temp=%d,Mode=%d,Event=%d,Bat=%d", lAngle, lUpperAngle, lButtomAngle, lTemp, lMode, lEvent, lBat);
  /* Обновляем информацию о датчике, если необходимо */
  isEvent = CheckAndSaveMac(mac, rssi);
  /* Если адрес совпал */
  if (isDataWrite(mac) == true)
  {
    /* Пишем данные */
    settag(ID_TAG, lId, true);
    settag(RSSI_TAG, rssi, true);
    settag(TEMP_TAG, lTemp, true);
    settag(BAT_TAG, lBat, true, 1);
    settag(ANGLE_TAG, lAngle, true);
    settag(UPPER_ANGLE_TAG, lUpperAngle, true);
    settag(BUTTOM_ANGLE_TAG, lButtomAngle, true);
    settag(MODE_TAG, lMode, true);
    settag(EVENT_TAG, lEvent, true);
    /* Переинициализируем таймер. Однократное срабатывание через 90 секунд если пакеты не поступят за это время */
    settimer (WAIT_TIME_LIMIT, true);
  }
  if (isEvent)
  {
    pushpoint();
  }
}

@timer()
{
    SetInvalid()
    pushpoint();
}
