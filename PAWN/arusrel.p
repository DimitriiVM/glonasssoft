/* 
 * Script arusrel.p
 * ver 1.0.0 with fw 4.4.0 (UMKa302x) or 1.7.0 (UMKa31x) or 1.2.0 (UMKa303)
 * (c) Copyright 2022, GLONASSsoft
 * This file is provided as is (no warranties).
 *
 * Скрипт предназначен для работы с беспроводным реле ArusNavi RELAY-BLE
 *
 * Настройки срипта:
 * Для корректной работы надо определить MAC адрес целевого реле с помощью команды "CHAT SETMAC=1A:2B:3C:4E:5D:6F",
 * где "1A:2B:3C:4E:5D:6F" - MAC-адрес целевого реле
 *
 * Парамерты скрипта:
 * 0  - Напряжение питания реле в Вольтах
 * 1  - RSSI в dbm
 * 2  - Состояние реле. 0 - реле НЗ замкнуто (CLOSE) 1 - реле НЗ разомкнуто (OPEN)
 *
 * По каждому изменению параметра 2 - Состояние реле формируется дополнительня точка в черном ящике терминала
 *
 * Команды скрипта:
 * 1) "CHAT STATUS" - запросить текущее состояние реле
 * Ответы: 
 * "UNKNOWN" - статус не определен. Повторите команду позже. Реле недоступно или статус не обновлен после команды
 * "CLOSE" - реле НЗ замкнуто
 * "OPEN" - реле НЗ разомкнуто
 * 2) "CHAT CLOSE" - Замкнуть НЗ реле
 * Ответы:  
 * "CLOSING" - отправлена команда на замыкание НЗ реле
 * "CLOSE" - реле НЗ уже замкнуто
 * 3) "CHAT OPEN" - Разомкнуть НЗ реле
 * Ответы:  
 * "OPENING" - отправлена команда на размыкание НЗ реле
 * "OPEN" - реле НЗ уже разомкнуто
 * 4) "CHAT SILENT" - перейти в режим радиомолчания и не управлять состоянием реле
 * Ответы:  
 * "SILENCE" - переход в режим радиомолчания
 * 5) "CHAT SETMAC=1A:2B:3C:4E:5D:6F" - задать MAC-адрес целевого реле.
 * Ответы:  
 * "MAC=1A:2B:3C:4E:5D:6F"
 * 6) "CHAT INFO" - Возвращает информацию о имени, версии и настройках скрипта
 * Ответы:
 * "ARUSREL VER=1.0.0 MAC=1A:2B:3C:4E:5D:6F"
 */
#include <string>
#include <time>
#include tracker
#include ble

#pragma dynamic 128

#define VERSION     "1.0.0"

#define DEFAULT_TO  3600 /* Время в секундах, на которое нужно замкнуть (или разомкнуть? это не понятно из РЭ) реле. Диапазон от 1 до 1000000 секунд */

#define ARUSREL_EEP_MAGIC   0x4152524C   /* Магическое значение "ARRL" */

#define BAT_TAG     0   /* Напряжение батареи */
#define RSSI_TAG    1   /* RSSI */
#define RELAY_TAG   2   /* Состояние реле */

#define WAIT_TIME_LIMIT     90000 /* 90 секунд ждем пакеты, прежде чем говорить что метка не присылает данные */

const RELAY_STATE_UNKNOWN = -1
const RELAY_STATE_CLOSE   = 0
const RELAY_STATE_OPEN    = 1
 
const RELAY_COMMAND_OPEN  = 0x07
const RELAY_COMMAND_CLOSE = 0x08

new gMac[6]
new gRelay = RELAY_STATE_UNKNOWN

//******************************************************************************
// Функция сохраняет MAC-адрес в EEPROM
//******************************************************************************
mac_save_eep(Mac[6])
{
  seteep(0, ARUSREL_EEP_MAGIC)
  seteep(1, Mac[0])
  seteep(2, Mac[1])
  seteep(3, Mac[2])  
  seteep(4, Mac[3])
  seteep(5, Mac[4])
  seteep(6, Mac[5])
}

//******************************************************************************
// Функция чтения MAC-адрес из EEPROM
//******************************************************************************
mac_load_eep(Mac[6])
{
  if (geteep(0) == ARUSREL_EEP_MAGIC)
  {
    Mac[0] = geteep(1)
    Mac[1] = geteep(2)
    Mac[2] = geteep(3)
    Mac[3] = geteep(4)
    Mac[4] = geteep(5)
    Mac[5] = geteep(6)
  }
  else
  {
    Mac[0] = 0x1A
    Mac[1] = 0x2B
    Mac[2] = 0x3C
    Mac[3] = 0x4E
    Mac[4] = 0x5D
    Mac[5] = 0x6F
  }
}

/* Преобразование HEX-символа в бинарное число */
hex2bin(Sym)
{
  if ('0' <= Sym <= '9')
    return Sym - '0'
  if ('A' <= Sym <= 'F')
    return Sym - 'A' + 10
  if ('a' <= Sym <= 'f')
    return Sym - 'a' + 10  
  return -1
}

/* Преобразование строки в MAC */
str2mac(TextMac{}, Start, Mac[6])
{
  for (new i = 0; i < sizeof(Mac); i++)
  {
    new Hi = hex2bin(TextMac{Start + 0 + i * 3})
    new Lo = hex2bin(TextMac{Start + 1 + i * 3})
    if ((Hi < 0) || (Lo < 0)) 
      return -1
    Mac[i] = (Hi << 4) | Lo
  }
  return sizeof(Mac)
}

/* Запуск скрипта */
main()
{
  mac_load_eep(gMac)
  printf("MAC=%x:%x:%x:%x:%x:%x", gMac[0], gMac[1], gMac[2], gMac[3], gMac[4], gMac[5])  
  bleadvertsubsmac(gMac)
}

/* Обработка пакета */
@bleadvertrecv0(mac[6], rssi, data[31], len)
{
  new lRelay  /* Реле */  
  new lBat    /* Батарея */
  
  printf("MAC=%x:%x:%x:%x:%x:%x,RSSI=%d,Len=%d", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5], rssi, len)
  /* Валидация заголовка. В данной реалзиации поддерживается только пакет со временем и данными */
  if ((len != 8) || (BLE_GAP_LEN(data) != 7) || (BLE_GAP_DATA(data, 0) != 0x16) || (BLE_GAP_DATA(data, 1) != 0x0F) || (BLE_GAP_DATA(data, 2) != 0x64)) return
  /* Разбор данных */
  lRelay = (BLE_GAP_DATA(data, 3) == RELAY_STATE_OPEN);
  lBat   =  BLE_GAP_DATA(data, 4)
  /* Пишем данные */
  settag(BAT_TAG, lBat, true, 1)
  settag(RSSI_TAG, rssi)
  settag(RELAY_TAG, lRelay)
  // Сохраняем точку если изменилось состояние реле
  if (gRelay != lRelay)
    pushpoint()
  gRelay = lRelay
  /* Переинициализируем таймер. Однократное срабатывание через 90 секунд если пакеты не поступят за это время */
  settimer(WAIT_TIME_LIMIT, true)
}

/* Обработка таймаута */
@timer()
{
  settag(BAT_TAG, 0, false)
  settag(RSSI_TAG, 0, false)
  settag(RELAY_TAG, 0, false)
  // Сохраняем точку если изменилось состояние реле
  if (gRelay != RELAY_STATE_UNKNOWN)
    pushpoint()
  gRelay = RELAY_STATE_UNKNOWN
}

/* Передать команду в реле */
bool: RelayCommand(Mac[6], Cmd, Timeout = DEFAULT_TO)
{
  new data[13] = [ 0x41, 0xFF, 0x46, 0xA2, 0x5E, 0x71, 0x77, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00 ]

  data[2]  = Mac[5] & 0xFF
  data[3]  = Mac[4] & 0xFF
  data[4]  = Mac[3] & 0xFF
  data[5]  = Mac[2] & 0xFF
  data[6]  = Mac[1] & 0xFF
  data[7]  = Mac[0] & 0xFF
  data[8]  = Cmd
  data[9]  = (Timeout >> 0)  & 0xFF
  data[10] = (Timeout >> 8)  & 0xFF
  data[11] = (Timeout >> 16) & 0xFF
  data[12] = (Timeout >> 24) & 0xFF
  return bleadvertbroadcast(data)
}

/* Командный интерфейс */
@chat(string{128})
{
  if (strequal(string, "OPEN", true))
  { 
    RelayCommand(gMac, RELAY_COMMAND_OPEN)
    if (gRelay != RELAY_STATE_OPEN)
    {
      strcopy(string, "OPENING");
      gRelay = RELAY_STATE_UNKNOWN
    }
    else
      strcopy(string, "OPEN");
  }
  else if (strequal(string, "CLOSE", true))
  {
    RelayCommand(gMac, RELAY_COMMAND_CLOSE)
    if (gRelay != RELAY_STATE_CLOSE)
    {
      strcopy(string, "CLOSING");      
      gRelay = RELAY_STATE_UNKNOWN    
    }
    else
      strcopy(string, "CLOSE");
  }
  else if (strequal(string, "STATUS", true))
  {
    if (gRelay == RELAY_STATE_UNKNOWN)
      strcopy(string, "UNKNOWN");
    else if (gRelay == RELAY_STATE_CLOSE)
      strcopy(string, "CLOSE");
    else if (gRelay == RELAY_STATE_OPEN)
      strcopy(string, "OPEN");
  }
  else if (strequal(string, "SILENT", true)) 
  {
    bleadvertradiosilence()
    strcopy(string, "SILENCE");
  }
  else if (strequal(string, "SETMAC=", true, 7)) 
  {
    bleadvertunsubscribe(0)
    str2mac(string, 7, gMac)
    mac_save_eep(gMac)
    mac_load_eep(gMac)
    printf("MAC=%x:%x:%x:%x:%x:%x", gMac[0], gMac[1], gMac[2], gMac[3], gMac[4], gMac[5])  
    bleadvertsubsmac(gMac)
    strformat(string, sizeof(string), true, "MAC=%x:%x:%x:%x:%x:%x", 
      gMac[0], 
      gMac[1], 
      gMac[2], 
      gMac[3], 
      gMac[4], 
      gMac[5])
  }  
  else if (strequal(string, "INFO", true))
  {
    strformat(string, sizeof(string), true, "ARUSREL VER=%s MAC=%x:%x:%x:%x:%x:%x", 
      VERSION, 
      gMac[0], 
      gMac[1], 
      gMac[2], 
      gMac[3], 
      gMac[4], 
      gMac[5])
  }
}
