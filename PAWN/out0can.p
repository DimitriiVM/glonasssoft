/*
Скрипт по команде включает выход, и через заданное время выключает его
*/

#include <time>
#include <string>
#include tracker

#define OUTTIMER 30000 //Указываем время в МС через которое выключаем
#define OUTPUT 0 //Укахывает номер выхода
#define TIMER 5000

main()
{//start main
  printf"Start Ok"
  settimer(TIMER)
}//end main

@chat(string{128})//Обработка поступившей команды
{//start chat
  if (strequal(string, "SETOUTON", true))
  {//start if
    printf "Команда SETOUTON принята"
    setout (OUTPUT, true)//Включаем выход
    printf("Выход %d активирован", OUTPUT)
    delay(OUTTIMER)//Ждем перед тем как выключить выход
    setout (OUTPUT, false)//Выключаем выход
    printf("Выход %d деактивирован", OUTPUT)
  }//end if
  else
  {//start else
    printf "Команда не распозна"
  }//end else
}//end chat

@timer()
{
  printf("ПОДГОТОВИЛ:")
  printf("Дмитрий Витальевич Мельник")
  printf("i.x.c.o.n@yandex.ru")
}
