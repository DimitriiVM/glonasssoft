/*
Пример работы с BLE
*/
#include <string>
#include tracker
#include ble

#pragma dynamic 128

/* Запуск скрипта */
main()
{
  bleadvertsubscribe() /* Вся реклама BLE_GAP_MFR_SPEC_DATA в обработчике 0 */
  bleadvertsubsmac([0xDC,0xAC,0xD8,0x59,0x38,0x19], BLE_GAP_MFR_SPEC_DATA, 1) /* Реклама BLE_GAP_MFR_SPEC_DATA по заданному MAC в обработчике 1 */
}

/* Обработка широковещательного пакета */
@bleadvertrecv0(mac[6], rssi, data[31], len)
{
  printf("MAC=%d,%d,%d,%d,%d,%d", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5])
  printf("RSSI=%d,LEN=%d", rssi, len)
  bleadvertunsubscribe(0) /* Описка по первому пакеу от широковещательной рекламы */
  bleadvertsubsmac(mac, BLE_GAP_MFR_SPEC_DATA, 2) /* Реклама BLE_GAP_MFR_SPEC_DATA по заданному MAC в обработчике 2 */
}

/* Обработка по заданному MAC */
@bleadvertrecv1(mac[6], rssi, data[31], len)
{
  printf("FIXEDMAC1")
  printf("RSSI=%d,LEN=%d", rssi, len)
}

/* Обработка по заданному MAC */
@bleadvertrecv2(mac[6], rssi, data[31], len)
{
  printf("FIXEDMAC2")
  printf("RSSI=%d,LEN=%d", rssi, len)
}
