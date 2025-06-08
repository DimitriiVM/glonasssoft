//Пример  работы с дисплеем
//Формат посылок:
//#str0# 16 byte # - первая строка, байты только  латиница
//#str1# 16 byte # - вторая строка, байты только  латиница

#include <time>
#include serial

#pragma dynamic       256

rsstr0()
{
  new buffer[] = [0x23, 0x73,0x74,0x72,0x30,0x23,0x47,0x4c,0x4f,0x4e,0x41,0x53, 0x53, 0x53, 0x4f, 0x46,  0x54,  0x23];
  rssend(buffer, sizeof(buffer));
}

main()
{
    
    for(;;)
    {
        if (rsopen() == true) // Открываем последовательный порт на скорости по умолчанию и проверяем успешность операции
        {
          printf("RS485 START OK");
          rsstr0();
        }
        delay(1000); // Повторяем каждые 100 мсек
    }
}
