/*
Пример работы с CAN шиной
*/
#include <string>
#include tracker
#include can

#pragma dynamic 128

/* Запуск скрипта */
main()
{
  /* Передача */
  new Buff[8]

  Buff[0] = 3 // Формируем данные для передачи
  Buff[1] = 4
  cansend(0x7E0, 2, Buff) // Передаем пакет длиной 2 байта по id 0x7E0

  /* Фильтр */
  addcanfilter(0x651) // Добавляем фильтр CAN для сообщений с id 0x651
  /* Здесь можно настроить дополнительные фильтры CAN */
}

/* Обработка пакета */
@canrecv(id, dlc, data[8])
{
  /* Выводим информацию о поступивших пакетах */
  printf("ID=%d,DLC=%d", id, dlc) 
  printf("%d,%d,%d,%d,%d,%d,%d,%d", data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7])
}
