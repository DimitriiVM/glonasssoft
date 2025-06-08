/*
Пример работы с акселерометром по событию
*/
#include <time>
#include tracker

#pragma dynamic       32

@accupdate() // Обработчик собятия по поступлению данных от акселерометра
{
  new acc[.x, .y, .z]

  printf "accupdate"  
  getacc(acc) // Читаем данные
  settag(0, acc.x) // Пишем данные о ускорении по оси X в ячейку 0
  settag(1, acc.y) // Пишем данные о ускорении по оси Y в ячейку 1
  settag(2, acc.z) // Пишем данные о ускорении по оси Z в ячейку 2
  pushpoint() // Записываем точку в архив
}

